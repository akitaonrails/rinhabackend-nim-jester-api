import asyncdispatch, uuids, times
import std/[options,json]
import database, types
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
      id: some(uuid),
      apelido: "foo",
      nome: some("nome"),
      nascimento: some("2000-01-01"),
      stack: some(@["foo", "bar", "baz"]))

    try:
      waitFor insertPessoa(pessoa)
    except:
      raise newException(IOError, "I can't do that Dave.")

    let total = waitFor getPessoasCount()
    check(total == 1)

    let res = waitFor getPessoaById(uuid)
    case res
    of Some(@pessoa):
      check(pessoa.id.get() == uuid)
    of None():
      raise newException(IOError, "I can't do that Dave.")

    let results = waitFor searchPessoas("foo")
    check(len(results) == 1)

  test "json parsing":
    let body = """
      {
        "apelido": "jose",
        "nome": "Jose Roberto",
        "nascimento": "2000-02-01",
        "stack": ["foo", "bar", "baz"]
       }
    """
    let json = parseJson(body)

    let pessoa = to(json, Pessoa)
    check(pessoa.apelido == "jose")
