# nimDot
Generating Graphviz dot files from Nim source code

This code searches for functions (*proc*s) in Nim's libraries which are manipulating container types (seq, Table, etc.), or other basic types (string, expr, float, etc.). Then it creates a Graphviz dot file for each of these showing what type of parameters are required for these functions. Some example png files generated from these dot files (see output folder for all of them):

![Table](https://raw.githubusercontent.com/petermora/nimDot/master/output/Table.png)
![openArray](https://raw.githubusercontent.com/petermora/nimDot/master/output/openArray.png)
