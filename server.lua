local luarpc = require("luarpc")

if #arg ~= 1 then
        error("Usage: lua server.lua <interface> ")
end


local arq_interface = arg[1]


myobj1 = { foo = 
             function (a, b, s)
               return a+b, "alo alo"
             end,
          boo = 
             function (n)
               return n
             end
        }
myobj2 = { foo = 
             function (a, b, s)
               return a-b, "tchau"
             end,
       	   boo = 
       	      function (n)
       	        return 1
       	      end,
	   bar = 
              function (a, s, mstruct, b)
		 return  a*mstruct["fields"]["peso"] - b, b
              end
        }


ip, p = luarpc.createServant(arq_interface, myobj1)
print("IP:", ip, "PORT:", p, "for server 1")

ip2, p2 = luarpc.createServant(arq_interface, myobj2)
print("IP:", ip2, "PORT:", p2, "for server 2")

luarpc.waitIncoming()

