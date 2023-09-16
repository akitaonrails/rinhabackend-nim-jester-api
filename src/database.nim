import asyncdispatch, strutils, sequtils, strformat, os
import std/options
import pg
import std/json
import types

# Initialize Database
var global_pool* {.threadvar.}: AsyncPool

proc initDb*() =
  let pgconf = parseEnv()

  var retries = 0
  while retries < 4:
    try:
      global_pool = newAsyncPool(pgconf.hostname, pgconf.username, pgconf.password, pgconf.database, pgconf.poolSize)
      return
    except:
      sleep(5000)
      inc(retries)

  quit(0)

proc getGlobalPool(): AsyncPool =
  if global_pool.isNil:
    initDb()
  return global_pool

proc createPessoaTable*() {.async.} =
  let sqlQueries = sql"""
    CREATE EXTENSION IF NOT EXISTS pg_trgm;

    DROP TABLE IF EXISTS public.pessoas CASCADE;
    CREATE TABLE public.pessoas (
        id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
        apelido character varying(32) NOT NULL,
        nome character varying(100) NOT NULL,
        nascimento timestamp(6) without time zone,
        stack character varying,
        searchable text GENERATED ALWAYS AS ((((((nome)::text || ' '::text) || (apelido)::text) || ' '::text) || (COALESCE(stack, ' '::character varying))::text)) STORED
    );

    CREATE INDEX IF NOT EXISTS index_pessoas_on_id ON public.pessoas (id);

    CREATE UNIQUE INDEX IF NOT EXISTS index_pessoas_on_apelido ON public.pessoas USING btree (apelido);

    CREATE INDEX IF NOT EXISTS index_pessoas_on_searchable ON public.pessoas USING gist (searchable public.gist_trgm_ops);
  """
  await getGlobalPool().exec(sqlQueries, @[])

# Insert a new Pessoa
proc insertPessoa*(pessoa: Pessoa) {.async.} =
  let query = sql"""
    INSERT INTO public.pessoas (id, apelido, nome, nascimento, stack)
    VALUES (?, ?, ?, ?::timestamp(6), ?);
  """
  await getGlobalPool().exec(query, @[pessoa.id.get(), pessoa.apelido, pessoa.nome.get(), pessoa.nascimento.get(), $(%*(pessoa.stack.get()))])

# Get the count of Pessoas
proc getPessoasCount*(): Future[int] {.async.} =
  let query = sql"""
    SELECT COUNT(*) FROM public.pessoas;
  """
  let result = await getGlobalPool().rows(query, @[])
  return parseInt(result[0][0])

# Get Pessoa by ID
proc getPessoaById*(id: string): Future[Option[Pessoa]] {.async.} =
  let query = sql"""
    SELECT id::text, apelido, nome, to_char(nascimento, 'YYYY-MM-DD'), stack
    FROM public.pessoas
    WHERE id = ?;
  """
  try:
    let result = await getGlobalPool().rows(query, @[id])
    if len(result) == 0:
      return none(Pessoa)

    let row = result[0]
    return some(Pessoa(
      id: some(row[0]),
      apelido: row[1],
      nome: some(row[2]),
      nascimento: some(row[3]),
      stack: some(row[4].split(","))))
  except:
    return none(Pessoa)

# Search Pessoas based on term
proc searchPessoas*(term: string): Future[seq[Pessoa]] {.async.} =
  let query = sql"""
    SELECT id::text, apelido, nome, to_char(nascimento, 'YYYY-MM-DD'), stack
    FROM public.pessoas
    WHERE searchable ILIKE ?;
  """
  let result = await getGlobalPool().rows(query, @["%" & term & "%"])
  if len(result) == 0:
    return @[]

  return result.mapIt(Pessoa(
    id: some(it[0]),
    apelido: it[1],
    nome: some(it[2]),
    nascimento: some(it[3]),
    stack: some(it[4].split(","))
    ))
