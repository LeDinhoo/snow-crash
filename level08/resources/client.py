#!/usr/bin/env python3
import socket
import struct


SOCKET_PATH = "/run/blacksun/blacksun.sock"
VERSION = 1


def checksum(payload):
    result = 0
    for index, byte in enumerate(payload):
        result ^= byte ^ (index & 0xFF)
    return result


def send_message(sock, command, state, payload=b"", response_lines=1):
    first_byte = VERSION | (state << 3) | (command << 5)
    # The fields use 7 bytes; the service reads an 8-byte raw header.
    header = bytes([first_byte]) + struct.pack(
        "<IHB", len(payload), checksum(payload), 0
    )
    sock.sendall(header + payload)

    response = bytearray()
    while response.count(b"\n") < response_lines:
        chunk = sock.recv(1)
        if not chunk:
            break
        response.extend(chunk)
    return response.decode()


with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
    sock.connect(SOCKET_PATH)
    print(send_message(sock, command=0, state=0, payload=b"\xad\xde"), end="")
    print(send_message(sock, command=2, state=1, response_lines=2), end="")
