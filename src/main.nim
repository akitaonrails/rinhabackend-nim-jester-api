# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.
import database
import jester

proc main() =
  echo "Hello, world!"

when isMainModule:
  main()
