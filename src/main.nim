# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
import asyncdispatch, jester, strutils, uuids, times
import std/json
import database
{.experimental: "caseStmtMacros".}

import fusion/matching
router rinha_api:
  get "/contagem-pessoas":
    let count = await getPessoasCount()
    resp $count

  get "/pessoas/@pessoa_id":
    let res = await getPessoaById(@"pessoa_id")
    case res
    of Some(@pessoa):
      resp(Http200, $toJson(pessoa))
    of None():
      resp(Http400, "")

  get "/pessoas":
    if request.params.hasKey("t"):
      let results = await searchPessoas(request.params["t"])
      resp(Http200, $toJson(results))
    else:
      resp(Http404, "")

  post "/pessoas":
    let data = parseJson(request.body)
    let nested = to(data, NestedPessoa)
    let pessoa = nested.pessoa

    let uuid = $genUUID()
    pessoa.id = uuid
    await insertPessoa(pessoa)
    # headers.add("Location", "/pessoas/" & uuid)
    resp(Http201, "")

proc main() =
  let settings = newSettings(port=Port(3000))
  var jester = initJester(rinha_api, settings=settings)

  initDb()
  waitFor createPessoaTable()
  jester.serve()

when isMainModule:
  main()
