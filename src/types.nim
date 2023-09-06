import std/[options,json]
import os, strutils

# Config definition
type
  PgConfig* = object
    hostname*: string
    port*: int
    username*: string
    password*: string
    database*: string
    poolSize*: int

proc parseEnv*() : PgConfig =
  var config = PgConfig()
  let hostname = getEnv("DB_HOST")
  if len(hostname) == 0:
    config.hostname = "localhost"
  else:
    config.hostname = hostname

  try:
    let port = parseInt(getEnv("DB_PORT"))
    config.port = port
  except:
    config.port = 5432

  let username = getEnv("DB_USERNAME")
  if len(username) == 0:
    config.username = "postgres"
  else:
    config.username = username

  let password = getEnv("DB_PASSWORD")
  if len(password) == 0:
    config.password = "password"
  else:
    config.password = password

  let database = getEnv("DB_DATABASE")
  if len(database) == 0:
    config.database = "postgres"
  else:
    config.database = database

  try:
    let poolSize = parseInt(getEnv("DB_POOL_SIZE"))
    config.poolSize = poolSize
  except:
    config.poolSize = 10

  return config

# Model definition
type
  Pessoa* = ref object of RootObj
    id*: Option[string]
    apelido*: string
    nome*: Option[string]
    nascimento*: Option[string]
    stack*: Option[seq[string]]

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
