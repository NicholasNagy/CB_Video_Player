import 'package:player_test/video_page.dart';

import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

void main() => runApp(VideoPage());

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

// Please note: I don't handle the end of the list.
class _AppState extends State<App> {
  List<BetterPlayerController> controllers = [];
  List<Map<String, dynamic>> videos = [];
  int totalPages = 0;
  bool initPageReady = true;
  int prevIndex = -1;

  @override
  initState() {
    super.initState();
    print("WTF is hapenning?1");
    //getPage(1);
    controllers.add(createController(0));
    controllers.add(createController(0));
    controllers.add(createController(0));
    controllers.add(createController(0));
    controllers.add(createController(0));
    print("WTF is hapenning?2");
  }

  Widget getNext(BuildContext context, int index) {
    // controllers[(index - 2) % 5].dispose();
    // controllers[(index - 2) % 5] = index > prevIndex || index - 2 < 0
    //     ? createController(index + 3)
    //     : createController(index - 2);

    // controllers[index % 5].play();
    // prevIndex = index;

    // // Potential async problem, because we are not waiting for the next pages
    // // to be retrieved. In TikTok, I noticed that a swipe will simply fail
    // // if it doesn't get the next videos. Perhaps we can somehow tell the
    // // builder that this is the last component to have a similar effect.
    // // Until we get the next page of course.
    // if (index % 50 > 40) {
    //   getPage(totalPages + 1);
    // }
    var k = controllers[index % 5];
    k.play();
    var v = controllers[(index - 1) % 5];
    v.pause();
    return GestureDetector(
      child: BetterPlayer(controller: k),
      onTap: () {
        print(k.isPlaying());
        if (k.isPlaying()!) {
          k.pause();
        } else {
          k.play();
        }

        print("something");
      },
    );
  }

  void getPage(int page) async {
    var data = {'page': page};
    var url = 'http://34.95.37.246:8000/videos';
    String body = json.encode(data);
    print("hi");
    http.Response response = await http.post(Uri.parse(url),
        headers: {"Content-Type": "application/json"}, body: body);
    print("hilo");
    if (response.statusCode == 200) {
      var resBody = jsonDecode(response.body) as Map<String, dynamic>;
      print(resBody);
      setState(() {
        resBody["data"].forEach((dynamic value) {
          videos.add(value);
        });
        totalPages = page;
        initPageReady = true;
      });
    } else {
      print("fml");
      // FML
    }
  }

  BetterPlayerController createController(int index) {
    return BetterPlayerController(
        BetterPlayerConfiguration(
            aspectRatio: 9 / 16, autoPlay: false, looping: true),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          "https://replied-resources.s3.amazonaws.com/transcoded-videos/RivQBjWB25ddrJcDTZaQWERRVsF3/b7b93bc9-2362-48be-a64d-34fa13d164ce/master.m3u8",
        ));
  }

  @override
  Widget build(BuildContext context) {
    // if (initPageReady) {
    //   for (int number = 0; number < 5; number++) {
    //     controllers.add(createController(number));
    //   }
    // }

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

// import 'package:flutter/material.dart';

// void main() => runApp(App());

// class App extends StatelessWidget {
//   const App({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.black,
//       child: MaterialApp(
//         home: Scaffold(
//           body: Center(
//             child: Text(
//               "Hello World",
//               style: TextStyle(color: Colors.black),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
