#!/usr/bin/env lua

local luarpc = require("luarpc")
local socket = require("socket")

if #arg ~= 4 then
	error("Usage: lua clientrpc.lua <interface> <IP> <PORT1> <PORT2>")
end

local file_interface = arg[1] 
local ip = arg[2]
local port = arg[3]
local port2 = arg[4]

local mstruct = {
    name = "minhaStruct",
    fields = {
        nome = "Jenifer",
        peso = "52",
        idade = "30"
    }
}


local p1 = luarpc.createProxy(file_interface, ip, port)
local p2 = luarpc.createProxy(file_interface, ip, port2)


ret, s = p1.foo(1, 2)
ret2, s2 = p1.foo(1, 2)
ret3, s3 = p1.foo(3, 4)
ret4 = p1.boo(5)
print(ret, s)
print(ret2, s2)
print(ret3, s3)
print(ret4)

ret5 = p2.boo(5)
ret6, s6 = p2.foo(3, 4)
ret7 = p2.boo(3) 
print(ret5)
print(ret6, s6)
print(ret7)

ret8 = p2.bar(2, "hello", mstruct, 10)
print(ret8)

