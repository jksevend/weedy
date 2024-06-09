import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 16),
            children: <TextSpan>[
              const TextSpan(text: '🚧 '),
              const TextSpan(
                  text: 'The statistics feature is in development. Check out the progress '),
              TextSpan(
                text: 'here',
                style: const TextStyle(color: Colors.blue),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    const url = 'https://github.com/jksevend/weedy';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      throw 'Could not launch $url';
                    }
                  },
              ),
              const TextSpan(text: ' 🚧'),
            ],
          ),
        ),
      ],
    ));
  }
}
