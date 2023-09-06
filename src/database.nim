import asyncdispatch, strutils, sequtils, times
import std/options
import pg
import std/json

# Model definition
type
  Pessoa* = ref object of RootObj
    id*: string
    apelido*: string
    nome*: string
    nascimento*: DateTime
    stack*: seq[string]

# Initialize Database
var global_pool*: AsyncPool

proc initDb*() =
  global_pool = newAsyncPool("localhost", "postgres", "password", "postgres", 10)

proc createPessoaTable*() {.async.} =
  let sqlQueries = sql"""
    CREATE EXTENSION IF NOT EXISTS pg_trgm;

    DROP TABLE public.pessoas CASCADE;
    CREATE TABLE public.pessoas (
        id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
        apelido character varying(32) NOT NULL,
        nome character varying(100) NOT NULL,
        nascimento timestamp(6) without time zone,
        stack character varying,
        created_at timestamp(6) without time zone NOT NULL,
        updated_at timestamp(6) without time zone NOT NULL,
        searchable text GENERATED ALWAYS AS ((((((nome)::text || ' '::text) || (apelido)::text) || ' '::text) || (COALESCE(stack, ' '::character varying))::text)) STORED
    );

    CREATE INDEX IF NOT EXISTS index_pessoas_on_id ON public.pessoas (id);

    CREATE UNIQUE INDEX IF NOT EXISTS index_pessoas_on_apelido ON public.pessoas USING btree (apelido);

    CREATE INDEX IF NOT EXISTS index_pessoas_on_searchable ON public.pessoas USING gist (searchable public.gist_trgm_ops);
  """
  await global_pool.exec(sqlQueries, @[])

# Insert a new Pessoa
proc insertPessoa*(pessoa: Pessoa) {.async.} =
  let query = sql"""
    INSERT INTO public.pessoas (id, apelido, nome, nascimento, stack, created_at, updated_at)
    VALUES (?, ?, ?, ?::timestamp(6), ?, NOW(), NOW());
  """
  var nascimento_str = (pessoa.nascimento).format("yyyy-MM-dd")
  await global_pool.exec(query, @[pessoa.id, pessoa.apelido, pessoa.nome, nascimento_str, $(%*(pessoa.stack))])

# Get the count of Pessoas
proc getPessoasCount*(): Future[int] {.async.} =
  let query = sql"""
    SELECT COUNT(*) FROM public.pessoas;
  """
  let result = await global_pool.rows(query, @[])
  return parseInt(result[0][0])

# Get Pessoa by ID
proc getPessoaById*(id: string): Future[Option[Pessoa]] {.async.} =
  let query = sql"""
    SELECT id::text, apelido, nome, to_char(nascimento, 'YYYY-MM-DD'), stack
    FROM public.pessoas
    WHERE id = ?;
  """
  let result = await global_pool.rows(query, @[id])
  if len(result) == 0:
    return none(Pessoa)

  let row = result[0]
  return some(Pessoa(
    id: row[0],
    apelido: row[1],
    nome: row[2],
    nascimento: parse(row[3], "yyyy-MM-dd"),
    stack: row[4].split(",")))

# Search Pessoas based on term
proc searchPessoas*(term: string): Future[seq[Pessoa]] {.async.} =
  let query = sql"""
    SELECT id::text, apelido, nome, to_char(nascimento, 'YYYY-MM-DD'), stack
    FROM public.pessoas
    WHERE searchable ILIKE ?;
  """
  let result = await global_pool.rows(query, @["%" & term & "%"])
  if len(result) == 0:
    return @[]

  return result.mapIt(Pessoa(
    id: it[0],
    apelido: it[1],
    nome: it[2],
    nascimento: parse(it[3], "yyyy-MM-dd"),
    stack: it[4].split(",")
    ))
