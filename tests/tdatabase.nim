import asyncdispatch, uuids, times
import std/options
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
      nascimento: parse("2000-01-01", "yyyy-MM-dd"),
      stack: @["foo", "bar", "baz"])

    try:
      waitFor insertPessoa(pessoa)
    except:
      raise newException(IOError, "I can't do that Dave.")

    let total = waitFor getPessoasCount()
    check(total == 1)

    let res = waitFor getPessoaById(uuid)
    case res
    of Some(pessoa):
      check(pessoa.id == uuid)
    of None():
      raise newException(IOError, "I can't do that Dave.")

    let results = waitFor searchPessoas("foo")
    check(len(results) == 1)
