import std/[options,json]

# Model definition
type
  Pessoa* = ref object of RootObj
    id*: Option[string]
    apelido*: string
    nome*: Option[string]
    nascimento*: Option[string]
    stack*: Option[seq[string]]

type
  NestedPessoa* = ref object of RootObj
    pessoa*: Pessoa

# serializers
proc toJson*(p: Pessoa): JsonNode =
  result = newJObject()
  result["id"] = %p.id
  result["apelido"] = %p.apelido
  result["nome"] = %p.nome
  result["nascimento"] = %p.nascimento
  result["stack"] = %p.stack

proc toJson*(p: seq[Pessoa]): JsonNode =
  result = newJArray()
  for pessoa in p:
    result.add(pessoa.toJson())

proc fromJson*(node: JsonNode, T: typedesc[Option[string]]): Option[string] =
  if node.kind == JString:
    return some(node.getStr)
  else:
    return none(string)

proc fromJson*(node: JsonNode, T: typedesc[Option[seq[string]]]): Option[seq[string]] =
  if node.kind == JArray:
    var arr: seq[string] = @[]
    for child in node:
      if child.kind == JString:
        arr.add(child.getStr)
    return some(arr)
  else:
    return none(seq[string])

proc fromJson*(node: JsonNode, T: typedesc[Pessoa]): Pessoa =
  new(result)
  for key, value in fieldpairs(result):
    node[key] = value

proc fromJson*(node: JsonNode, T: typedesc[NestedPessoa]): NestedPessoa =
  new(result)
  for key, value in fieldpairs(result):
    node[key] = value
