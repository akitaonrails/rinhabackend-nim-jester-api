import asyncdispatch, uuids, times
import std/options, std/json
import database
import unittest
{.experimental: "caseStmtMacros".}

import fusion/matching
suite "database testing":
  setup:
    initDb()
    waitFor createPessoaTable()

  test "simple scenario":
    let uuid = $genUUID()
    let pessoa = Pessoa(
      id: uuid,
      apelido: "foo",
      nome: "nome",
      nascimento: "2000-01-01",
      stack: @["foo", "bar", "baz"])

    try:
      waitFor insertPessoa(pessoa)
    except:
      raise newException(IOError, "I can't do that Dave.")

    let total = waitFor getPessoasCount()
    check(total == 1)

    let res = waitFor getPessoaById(uuid)
    case res
    of Some(@pessoa):
      check(pessoa.id == uuid)
    of None():
      raise newException(IOError, "I can't do that Dave.")

    let results = waitFor searchPessoas("foo")
    check(len(results) == 1)

  test "json parsing":
    let body = """
    {'pessoa':
      '{
        "apelido": "jose",
        "nome": "Jose Roberto",
        "nascimento": "2000-02-01",
        "stack": ["foo", "bar", "baz"]
       }
    }
    """
    let json = parseJson(body)

    let nested = to(json, NestedPessoa)
    check(nested.pessoa.apelido == "jose")
