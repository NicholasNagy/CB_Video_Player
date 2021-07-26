import 'better_player.dart';
import 'package:flutter/material.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    List<Widget> t = [];
    for (int number = 0; number < 100; number++) {
      t.add(TheBetterPlayer());
    }

    return MaterialApp(
        home: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView(
              children: t,
              scrollDirection: Axis.vertical,
            )));
  }
}
