import re, strutils, future, sequtils, tables, os

if commandLineParams().len != 1:
  echo "Please give the Nim folder as parameter"
  echo "for example: ./collectionsDot ~/download/Nim"
  quit(1)
let folder = commandLineParams()[0]

let folders = @["lib/system.nim", "lib/pure/collections/*",
    "lib/pure/strutils.nim"]

let raw = folders.map((p: string) =>
            toSeq(walkFiles(folder / p)).map(
              (filename: string) =>
                readFile(filename)).foldl(a&"\n"&b)
          ).foldl(a&"\n"&b)

proc createDot(filterFor: string) =
  var content = "digraph {\n"
  content.add("graph [\n")
  content.add("label = \"system.nim & collections/*\nfiltering for " &
    filterFor & "\";\n")
  content.add("rankdir=LR;\n")
  content.add("];\n")
  var nodeMap = initTable[string, int]()

  let lines = raw.splitLines
  for i in 0..<lines.len:
    var line = lines[i]
    if not @["proc", "template", "iterator"].map(
      (s: string) => line.contains(s))
      .foldl(a or b):
      continue
    # We allow proc definitions in three lines
    if line.count("(") > line.count(")") and i < lines.len-1:
      line = line & " " & lines[i+1]
    if line.count("(") > line.count(")") and i < lines.len-2:
      line = line & " " & lines[i+2]
    # place , in [] to ; (for example f[T,S](...) will became f[T;S](...))
    # and remove all content within {}
    # Before:
    #  proc len*[A, B](t: OrderedTable[A, B]): int {.inline.} =
    # After:
    #  proc len*[A; B](t: OrderedTable[A; B]): int =
    var lineReplaced = line.replacef(re"\[([^,\]]*),([^\]]*)\]","[$1;$2]")
        .replace("{.importc", "=").replacef(re"\{.*\}","")
    if lineReplaced.contains("="):
      var deep = 0
      var found = false
      var tick = false
      for p in 0..<lineReplaced.len:
        if lineReplaced[p] == '`':
          tick = not tick
        if lineReplaced[p] == '(':
          deep += 1
        elif lineReplaced[p] == ')':
          deep -= 1
        if deep == 0 and not tick and lineReplaced[p] == ':':
          found = true
          break
        if deep == 0 and not tick and lineReplaced[p] == '=':
          break
      if not found:
        lineReplaced = lineReplaced.replace("=", ":=")
    var matches : array[4, string]
    # If lineReplaced == "proc len*[A; B](t: OrderedTable[A; B]): int ="
    # then
    #  matches[0] = "proc"
    #  matches[1] = "len"
    #  matches[2] = "t: OrderedTable[A; B]"
    #  matches[3] = "int"
    if lineReplaced.match(
          re(".*(proc|template|iterator)" & # proc/template/iterator
            "\\ *" & # spaces
            "([^*]*)\\*" & # the function name and a star (*)
             "[^(]*\\(" & # we throw away the types like [T], opening (
             "([^)]*)\\)" & # parameters of the function, closing )
             "\\ *:\\ *([^{]*)"), # we require a return value
          matches):
      let fname = matches[1] #.replace(re"\[.*\]$","")
      # Let's split the parameters using comma, then restore ";" back to ","
      let paramsType = matches[2].split(",")
        .map((s: string) => s.replace(";", ","))
      let returnType = matches[3].strip().replace(";", ",")
        .replacef(re"=.*", "").strip()
      # If paramsType  == "h, maxHash: THash"
      # then paramsRemovedNames = [THash, THash]
      var paramsRemovedNames = paramsType.map(proc(s: string): string =
        if s.contains("="): s elif s.contains(":"): s.split(":")[1] else: "")
        .map(
          (s: string) => s.strip())
      for i in countdown(paramsRemovedNames.len-1, 1):
        if paramsRemovedNames[i-1].len == 0:
          paramsRemovedNames[i-1] = paramsRemovedNames[i]
      # If there is on parameter, or the first paramter has default value,
      # then we inject an empty node
      if paramsRemovedNames.len == 0 or paramsRemovedNames[0].contains("="):
        paramsRemovedNames = "" & paramsRemovedNames
      let first = paramsRemovedNames[0]
      # Skip this proc if the first parameter or the return value is not
      # matching to filterFor
      let filterforRe = re("^(|var )" & filterFor & "($|[^a-zA-Z])")
      if not first.match(filterForRe) and
          not returnType.match(filterForRe):
        continue
      # nodeMap is initially empty, we all the types we find
      # If we find a new type, then we create the node in the .dot file
      # and add this type to the table.
      for key in [first, returnType]:
        if not nodeMap.hasKey(key):
          nodeMap[key] = len(nodeMap)
          content.add("node[color=coral, style=filled, label=\"")
          content.add(key.replace("\"", "\\\"") &  "\" ] N")
          content.add($nodeMap[key] & ";\n")
      # edgeLabel = fname(param2, param3, ...)
      let edgeLabel = if paramsRemovedNames.len > 1:
          fname & "(" &
          foldl(paramsRemovedNames[1..paramsRemovedNames.len-1], a&", "&b)
          .replace("\\", "\\\\").replace("\"", "\\\"")&")"
        else:
          fname
      let edgeColor = case matches[0]
        of "iterator":
          "green"
        of "template":
          "blue"
        else:
          ""
      content.add("N" & $nodeMap[first] & " -> N" & $nodeMap[returnType])
      content.add(" [color=\"" & edgeColor & "\", label=\"")
      content.add(edgeLabel & "\" ];\n")

  content.add("}\n")
  let filename = filterFor & ".dot"
  echo "creating file ", filename
  writeFile(filename, content)

let patterns = @["seq", "CountTableRef", "CritBitTree", "DoublyLinkedList",
  "HashSet", "OrderedTableRef", "SinglyLinkedList", "Table", "TableRef",
  "openArray", "string", "File", "expr", "float", "int"]

for p in patterns:
  createDot(p)

echo()
echo "Under linux install graphviz package and run the following commands:"
for p in patterns:
  echo "dot -Tpng ", p, ".dot > ", p, ".png"
