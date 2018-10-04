import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MaterialApp(home: Home()));

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _toDoController = TextEditingController();
  List _toDoList = [];

  Map<String, dynamic> _lastRemoved;
  int _lastPositionRemoved;
  bool _estaAdd = true;
  Map<String, dynamic> _lastUpdated;
  int _lastPositionUpdated;
  String _infoBotao = "Inserir";
  String _infoLabel = "Nova Tarefa";
  BuildContext _context;
  

  @override
  void initState() {
    super.initState();

    // utiliza o then para chamar uma função quando terminar de retornar os dados.
    // passar o resultado dentro da funcao anonima.
    _readData().then((data) {
      setState(() {
        _toDoList = json.decode((data));
      });
    });
  }

  void _refresh() {
    setState(() {
      _toDoController.text = "";
      _toDoList.clear();
      _saveData();
    });
  }

  void _addOrUpdateToDo(bool insert) {
    if (insert) {
      debugPrint("adicionou");
      setState(() {
        Map<String, dynamic> novaTarefa = Map();
        novaTarefa["title"] = _toDoController.text;
        novaTarefa["ok"] = false;
        _toDoController.text = "";
        _toDoList.add(novaTarefa);
        _saveData();
      });
    } else {
      setState(() {
        Map<String, dynamic> tarefaEditada = Map();
        tarefaEditada["title"] = _toDoController.text;
        tarefaEditada["ok"] = _lastUpdated["ok"];
        _toDoController.text = "";
        _toDoList.insert(_lastPositionUpdated, tarefaEditada);
        _saveData();
        

        final snack = SnackBar(
                content: Text("Tarefa \"${_lastUpdated["title"]}\" editada!"),
                action: SnackBarAction(
                    label: "Desfazer",
                    onPressed: () {
                      setState(() {
                        _toDoList.removeAt(_lastPositionUpdated);
                        _toDoList.insert(_lastPositionUpdated, _lastUpdated);
                        _saveData();
                      });
                    }
                  ),
                duration: Duration(seconds: 2));
            Scaffold.of(_context).showSnackBar(snack);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tarefas"),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        actions: <Widget>[
          IconButton(onPressed: _refresh, icon: Icon(Icons.refresh))
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.fromLTRB(17.0, 1.0, 7.0, 1.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                      controller: _toDoController,
                      decoration: InputDecoration(
                          labelText: _infoLabel,
                          labelStyle: TextStyle(color: Colors.blueAccent))),
                ),
                RaisedButton(
                  color: Colors.blueAccent,
                  child: Text(_infoBotao),
                  textColor: Colors.white,
                  onPressed: () {
                    _addOrUpdateToDo(_estaAdd);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              child: ListView.builder(
                  padding: EdgeInsets.only(top: 10.0),
                  itemCount: _toDoList.length,
                  itemBuilder: buildItem),
              onRefresh: _refreshOrder,
            ),
          )
        ],
      ),
    );
  }

  Widget buildItem(context, index) {
    return Dismissible(
      key: Key(DateTime.now().millisecondsSinceEpoch.toString()),
      secondaryBackground: Container(
          color: Colors.green,
          child: Align(
            alignment: Alignment(0.9, 0.0),
            child: Icon(Icons.mode_edit, color: Colors.white),
          )),
      //direction: DismissDirection.startToEnd,
      background: Container(
          color: Colors.red,
          child: Align(
            alignment: Alignment(-0.9, 0.0),
            child: Icon(Icons.delete_outline, color: Colors.white),
          )),
      child: CheckboxListTile(
        title: Text(_toDoList[index]["title"]),
        value: _toDoList[index]["ok"],
        secondary: CircleAvatar(
            child: Icon(_toDoList[index]["ok"] ? Icons.check : Icons.error)),
        onChanged: (c) {
          setState(() {
            _toDoList[index]["ok"] = c;
            _saveData();
          });
        },
      ),
      onDismissed: (direction) {
        // Esquerda pra direita remover
        if (direction == DismissDirection.startToEnd) {
          setState(() {
            _lastRemoved = Map.from(_toDoList[index]);
            _lastPositionRemoved = index;
            _toDoList.removeAt(index);
            _saveData();

            final snack = SnackBar(
                content: Text("Tarefa \"${_lastRemoved["title"]}\" removida!"),
                action: SnackBarAction(
                    label: "Desfazer",
                    onPressed: () {
                      setState(() {
                        _toDoList.insert(_lastPositionRemoved, _lastRemoved);
                        _saveData();
                      });
                    }),
                duration: Duration(seconds: 2));
            Scaffold.of(context).showSnackBar(snack);
          });
        }
        // Direita pra esquerda editar
        else if (direction == DismissDirection.endToStart) {
          setState(() {
            _lastUpdated = Map.from(_toDoList[index]);
            _lastPositionUpdated = index;
            _toDoController.text = _lastUpdated["title"];
            _infoBotao = "Salvar";
            _infoLabel = "Editar Tarefa";
            _estaAdd = false;
            _toDoList.removeAt(index);
            _context = context;
          });
        }
      },
    );
  }

  Future<Null> _refreshOrder() async {
    await Future.delayed(
        Duration(seconds: 1)); // Não precisa de por isso qd tiver o server.
    setState(() {
      _toDoList.sort((a, b) {
        if (a["ok"] && !b["ok"]) return 1;
        if (!a["ok"] && b["ok"])
          return -1;
        else
          return 0;
      });
      _saveData();
    });
    return null;
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File("${directory.path}/data.json");
  }

  Future<File> _saveData() async {
    String data = json.encode(_toDoList);
    final file = await _getFile();
    return file.writeAsString(data);
  }

  Future<String> _readData() async {
    try {
      final file = await _getFile();
      return file.readAsString();
    } catch (e) {
      return null;
    }
  }
}
