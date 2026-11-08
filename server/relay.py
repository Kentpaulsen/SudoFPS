#!/usr/bin/env python3
"""PixelEscape relay server.

Pairs players by a short join code and forwards game traffic between them
over WebSocket. No game logic lives here; the host player's game is the
authority. Works behind Caddy or a Cloudflare Tunnel (plain ws on localhost).

Control messages are JSON text frames:
  client -> {"op":"host"}                      server -> {"op":"hosted","code":"K7QXM","id":1}
  client -> {"op":"join","code":"K7QXM"}       server -> {"op":"joined","code":"K7QXM","id":N,"peers":[1,...]}
  host   <- {"op":"peer_joined","id":N}        all    <- {"op":"peer_left","id":N}
  all    <- {"op":"closed","reason":"host_left"}
  client -> {"op":"ping"}                      server -> {"op":"pong"}
  errors    {"op":"error","reason":"..."}

Game messages are binary frames: 4-byte big-endian target id (0 = everyone
else in the room) followed by the payload. The server replaces the target id
with the sender's id before forwarding.

Built for websockets 10.x (Debian 12 package python3-websockets).
"""
import asyncio
import json
import logging
import os
import secrets
import signal
import struct
import time
from http import HTTPStatus

import websockets

HOST = os.environ.get("RELAY_HOST", "127.0.0.1")
PORT = int(os.environ.get("RELAY_PORT", "8090"))
MAX_PEERS = int(os.environ.get("RELAY_MAX_PEERS", "8"))
MAX_ROOMS = int(os.environ.get("RELAY_MAX_ROOMS", "200"))
MAX_MSG = 64 * 1024
CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no I, L, O, 0, 1
CODE_LEN = 5
VERSION = "1"

log = logging.getLogger("relay")
rooms = {}          # code -> Room
started = time.time()


class Room:
    def __init__(self, code, host_ws):
        self.code = code
        self.peers = {1: host_ws}
        self.next_id = 2
        self.created = time.time()

    def add(self, ws):
        pid = self.next_id
        self.next_id += 1
        self.peers[pid] = ws
        return pid


def new_code():
    for _ in range(100):
        c = "".join(secrets.choice(CODE_CHARS) for _ in range(CODE_LEN))
        if c not in rooms:
            return c
    raise RuntimeError("no free code")


async def send_json(ws, obj):
    try:
        await ws.send(json.dumps(obj))
    except websockets.ConnectionClosed:
        pass


async def send_bin(ws, data):
    try:
        await ws.send(data)
    except websockets.ConnectionClosed:
        pass


async def health(path, headers):
    """Plain HTTP answers for anything that is not a WebSocket upgrade."""
    if headers.get("Upgrade", "").lower() == "websocket":
        return None
    body = json.dumps({
        "service": "pixelescape-relay",
        "version": VERSION,
        "rooms": len(rooms),
        "players": sum(len(r.peers) for r in rooms.values()),
        "uptime_s": int(time.time() - started),
    }).encode() + b"\n"
    return HTTPStatus.OK, [("Content-Type", "application/json"),
                           ("Access-Control-Allow-Origin", "*")], body


async def handler(ws, path=None):
    room = None
    pid = 0
    try:
        async for msg in ws:
            if isinstance(msg, str):
                try:
                    m = json.loads(msg)
                    op = m.get("op")
                except (ValueError, AttributeError):
                    await send_json(ws, {"op": "error", "reason": "bad_json"})
                    continue
                if op == "ping":
                    await send_json(ws, {"op": "pong"})
                elif op == "host" and room is None:
                    if len(rooms) >= MAX_ROOMS:
                        await send_json(ws, {"op": "error", "reason": "server_full"})
                        continue
                    code = new_code()
                    room = Room(code, ws)
                    rooms[code] = room
                    pid = 1
                    log.info("room %s hosted (%d rooms)", code, len(rooms))
                    await send_json(ws, {"op": "hosted", "code": code, "id": 1})
                elif op == "join" and room is None:
                    code = str(m.get("code", "")).strip().upper()
                    r = rooms.get(code)
                    if r is None:
                        await send_json(ws, {"op": "error", "reason": "no_such_room"})
                        continue
                    if len(r.peers) >= MAX_PEERS:
                        await send_json(ws, {"op": "error", "reason": "room_full"})
                        continue
                    room = r
                    others = list(r.peers.keys())
                    pid = r.add(ws)
                    log.info("room %s: player %d joined (%d in room)", code, pid, len(r.peers))
                    await send_json(ws, {"op": "joined", "code": code, "id": pid, "peers": others})
                    for oid in others:
                        await send_json(r.peers[oid], {"op": "peer_joined", "id": pid})
                else:
                    await send_json(ws, {"op": "error", "reason": "bad_op"})
            else:
                if room is None or len(msg) < 4:
                    continue
                if len(msg) > MAX_MSG:
                    await send_json(ws, {"op": "error", "reason": "too_big"})
                    continue
                (target,) = struct.unpack(">I", msg[:4])
                out = struct.pack(">I", pid) + msg[4:]
                if target == 0:
                    for oid, ows in list(room.peers.items()):
                        if oid != pid:
                            await send_bin(ows, out)
                else:
                    tws = room.peers.get(target)
                    if tws is not None and target != pid:
                        await send_bin(tws, out)
    except websockets.ConnectionClosed:
        pass
    finally:
        if room is not None:
            room.peers.pop(pid, None)
            if pid == 1:
                rooms.pop(room.code, None)
                log.info("room %s closed (host left)", room.code)
                for ows in list(room.peers.values()):
                    await send_json(ows, {"op": "closed", "reason": "host_left"})
                    await ows.close()
            else:
                log.info("room %s: player %d left", room.code, pid)
                for ows in list(room.peers.values()):
                    await send_json(ows, {"op": "peer_left", "id": pid})


async def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    stop = asyncio.get_running_loop().create_future()
    for s in (signal.SIGINT, signal.SIGTERM):
        asyncio.get_running_loop().add_signal_handler(s, stop.set_result, None)
    async with websockets.serve(handler, HOST, PORT, process_request=health,
                                max_size=MAX_MSG + 16, ping_interval=20, ping_timeout=20):
        log.info("PixelEscape relay listening on %s:%d", HOST, PORT)
        await stop


if __name__ == "__main__":
    asyncio.run(main())
