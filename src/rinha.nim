# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
import asyncdispatch, jester, strutils, sequtils, uuids, os
import std/json
import database, types

router rinha_api:
  get "/contagem-pessoas":
    let count = await getPessoasCount()
    resp $count

  get "/pessoas/@pessoa_id":
    let res = await getPessoaById(@"pessoa_id")
    if isSome(res):
      resp(Http200, $toJson(res.get()))
    else:
      resp(Http404, "")

  get "/pessoas":
    if request.params.hasKey("t"):
      let results = await searchPessoas(request.params["t"])
      resp(Http200, $toJson(results))
    else:
      resp(Http400, "")

  post "/pessoas":
    try:
      let data = parseJson(request.body)
      let pessoa = to(data, Pessoa)

      let uuid = $genUUID()
      pessoa.id = some(uuid)
      if isNone(pessoa.stack):
        pessoa.stack = some(newSeq[string](0))

      if all(pessoa.stack.get(), proc (x: string): bool = x.len <= 32):
        await insertPessoa(pessoa)
        setHeader(responseHeaders, "Location", "/pessoas/" & uuid)
        resp(Http201, "")
      else:
        resp(Http400, "")
    except:
      resp(Http422, "")

proc main() =
  let port = parseInt(getEnv("PORT"))
  let settings = newSettings(port=Port(port))
  var jester = initJester(rinha_api, settings=settings)

  echo "initializing database"
  initDb()
  try:
    echo "creating table"
    waitFor createPessoaTable()
  except:
    echo "the other node already created everything"

  jester.serve()

when isMainModule:
  main()
