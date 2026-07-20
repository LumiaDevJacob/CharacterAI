"""
Lumia CharacterAI - local chat proxy.

neo.character.ai's chat websocket is behind Cloudflare, and Cloudflare
fingerprints the TLS handshake itself - a Roblox executor's raw socket
doesn't look like a real browser, so the connection gets dropped before it
ever reaches c.ai. This proxy runs on your machine, connects upstream using
curl_cffi (which impersonates a real browser's TLS fingerprint - the same
trick PyCharacterAI relies on), and relays plain JSON frames to and from the
executor over a local, unauthenticated websocket. The executor only ever
talks to 127.0.0.1; this process holds the real token and the real
connection to c.ai.

Setup:
    pip install curl_cffi websockets

Run:
    python proxy.py YOUR_TOKEN
    (or set CAI_TOKEN in the environment and just run `python proxy.py`)

Then point the module at it - see docs/api-notes.md / README.md.
"""

import asyncio
import json
import os
import sys

import websockets
from curl_cffi import AsyncSession

UPSTREAM_URL = "wss://neo.character.ai/ws/"
IMPERSONATE = "chrome124"


def get_token():
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.environ.get("CAI_TOKEN", "")


def get_port():
    return int(os.environ.get("CAI_PROXY_PORT", "8765"))


async def handle_client(local_ws, token):
    session = AsyncSession(impersonate=IMPERSONATE)

    try:
        upstream = await session.ws_connect(
            url=UPSTREAM_URL,
            cookies={"HTTP_AUTHORIZATION": f"Token {token}"},
        )
    except Exception as exc:
        print(f"[proxy] upstream connect failed: {exc}")
        await local_ws.send(json.dumps({"command": "neo_error", "comment": f"proxy upstream connect failed: {exc}"}))
        await session.close()
        return

    print("[proxy] upstream connected")

    async def upstream_to_local():
        try:
            while True:
                msg = await upstream.recv_str()
                await local_ws.send(msg)
        except Exception as exc:
            print(f"[proxy] upstream closed: {exc}")

    pump = asyncio.create_task(upstream_to_local())

    try:
        async for msg in local_ws:
            try:
                await upstream.send_json(json.loads(msg))
            except Exception as exc:
                print(f"[proxy] send to upstream failed: {exc}")
    finally:
        pump.cancel()
        try:
            await upstream.close()
        except Exception:
            pass
        await session.close()
        print("[proxy] client disconnected")


async def main():
    token = get_token()
    if not token:
        print("no token - pass it as an argument or set CAI_TOKEN")
        sys.exit(1)

    port = get_port()

    async def handler(ws):
        await handle_client(ws, token)

    print(f"[proxy] listening on ws://127.0.0.1:{port}, forwarding to {UPSTREAM_URL}")
    print("[proxy] point the module's WsProxyUrl at ws://127.0.0.1:%d" % port)

    async with websockets.serve(handler, "127.0.0.1", port):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
