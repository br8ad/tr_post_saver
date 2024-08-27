import 'package:flutter/material.dart';
import 'package:tr_post_saver/saving_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('테런 게시글 저장기 (by 꾸밈)'),
        ),
        body: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: MyCustomForm(),
        ),
      ),
    );
  }
}

class MyCustomForm extends StatefulWidget {
  const MyCustomForm({super.key});

  @override
  MyCustomFormState createState() => MyCustomFormState();
}

class MyCustomFormState extends State<MyCustomForm> {
  final _formKey = GlobalKey<FormState>();

  final ScrollController _scrollController = ScrollController();

  static const int kStartPage = 1;

  int startPage = kStartPage;
  int? endPage;
  int userCode = 0;

  // Checkboxes state
  bool bMedia       = true;
  bool bComment     = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Form(
      key: _formKey,

      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true, // 스크롤바 항상 표시

        child: ListView(
          controller: _scrollController,
          children: [

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB4B4B4), // 배경색 설정. 기본 보라 = 0xFF6750A4
                foregroundColor: Colors.white, // 텍스트 색상 설정
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                try {
                  await launchUrlString('https://github.com/br8ad/tr_post_saver/blob/main/README.md', webOnlyWindowName: '_blank');
                }
                catch (e) {
                  debugPrint(e.toString());
                  scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("에러 (새탭 열기 실패)")));
                }
              },   // 다일로그 안내 or github 링크 -> 링크가 최신 갱신 할수있긴 하겠다 & 런게 링크는 없어지니까
              child: const Text(
                '★ 상세 사항 ★',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Start Page TextField
            TextFormField(
              //controller: _startPageController,
              initialValue: '1',
              decoration: const InputDecoration(
                labelText: '시작 페이지',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '시작 페이지를 입력해주세요';
                }

                int? intValue = int.tryParse(value);
                if (intValue == null) {
                  return '숫자 값을 입력해주세요';
                }

                startPage = intValue;
                return null;
              },
            ),

            // End Page TextField
            TextFormField(
              //controller: _endPageController,
              decoration: const InputDecoration(
                labelText: '끝 페이지 (미설정 = 맨끝)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null;  // 비어 있을 경우 유효한 값임!
                }

                int? intValue = int.tryParse(value);
                if (intValue == null) {
                  return '숫자 값을 입력해주세요';
                }

                endPage = intValue;
                return null;
              },
            ),

            // User ID TextField
            // 광장 .com/뒤 숫자 라고 말하기. 8~9자네 ?
            TextFormField(
              //controller: _userIdController,
              decoration: const InputDecoration(
                labelText: '유저ID (★필수, 광장 링크에 있는 8글자 이상의 숫자)',  // 앞이 0이거나, 9를 넘어서 10글자일지도 모름
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '유저ID를 입력해주세요';
                }
                if (value.length < 8) {
                  return '유효한 ID값을 입력해주세요';
                }
                int? intValue = int.tryParse(value);
                if (intValue == null) {
                  return '숫자 값을 입력해주세요';
                }

                userCode = intValue;
                return null;
              },
            ),

            // Checkboxes
            CheckboxListTile(
              title: const Text('미디어 (영상(링크), 사진)'),
              value: bMedia,
              onChanged: (bool? value) {
                setState(() {
                  bMedia = value!;
                });
              },
            ),
            const Divider(height: 1),
            CheckboxListTile(
              title: const Text('댓글'),
              value: bComment,
              onChanged: (bool? value) {
                setState(() {
                  bComment = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF755FB1), // 배경색 설정. 기본 보라 = 0xFF6750A4
                foregroundColor: Colors.white, // 텍스트 색상 설정
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // 모든 필드가 유효할 때 실행할 코드
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                      SavingScreen(
                        startPage: startPage,
                        endPage:   endPage,
                        userCode:  userCode,
                        bComment:  bComment,
                        bMedia:    bMedia,
                      )
                    ),
                  );
                }
              },
              child: const Text(
                '글 저장 시작!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}