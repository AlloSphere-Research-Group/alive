local E = require "expr"
E:globalize()

foo = -1


a = Random(10)
print(a)
b = a * 10 + Min("foo", 1)
print(b)

b:conform()
print(b)

print(b:eval())
print(b())


print((E"foo")(_G))