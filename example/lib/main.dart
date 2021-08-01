import 'better_player.dart';
import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

// Please note: I don't handle the end of the list.
class _AppState extends State<App> {
  List<BetterPlayerController> controllers = [];
  List<Map<String, dynamic>> videos = [];
  int totalPages = 0;
  bool initPageReady = false;
  int prevIndex = -1;

  @override
  initState() {
    super.initState();
    getPage(1);
  }

  Widget getNext(BuildContext context, int index) {
    controllers[(index - 2) % 5].dispose();
    controllers[(index - 2) % 5] = index > prevIndex || index - 2 < 0
        ? createController(index + 3)
        : createController(index - 2);

    controllers[index % 5].play();
    prevIndex = index;

    // Potential async problem, because we are not waiting for the next pages
    // to be retrieved. In TikTok, I noticed that a swipe will simply fail
    // if it doesn't get the next videos. Perhaps we can somehow tell the
    // builder that this is the last component to have a similar effect.
    // Until we get the next page of course.
    if (index % 50 > 40) {
      getPage(totalPages + 1);
    }

    return BetterPlayer(controller: controllers[index % 5]);
  }

  void getPage(int page) async {
    var data = {'page': page};
    var url = 'http://34.95.37.246:8000/videos';
    String body = json.encode(data);
    http.Response response = await http.post(Uri.parse(url),
        headers: {"Content-Type": "application/json"}, body: body);
    if (response.statusCode == 200) {
      var resBody = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        resBody["data"].forEach((dynamic value) {
          videos.add(value);
        });
        totalPages = page;
        initPageReady = true;
      });
    } else {
      // FML
    }
  }

  BetterPlayerController createController(int index) {
    return BetterPlayerController(
      BetterPlayerConfiguration(
          aspectRatio: 9 / 16, autoPlay: false, looping: true),
      betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network, videos[index]["manifestUrl"]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (initPageReady) {
      for (int number = 0; number < 5; number++) {
        controllers.add(createController(number));
      }
    }

    return MaterialApp(
        home: initPageReady
            ? Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                  itemBuilder: getNext,
                  scrollDirection: Axis.vertical,
                ))
            : Text("Waiting to load initial page..."));
  }
}
