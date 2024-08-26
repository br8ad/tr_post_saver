import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

// 뒤로 가기는 없게할까? -> 이전 화면을 pop해버리면 컨트롤러도 dispose해버리면 되니까 훔
// -> 그게 더 힘드네. popAndPushNamed인데, name 넣기도 귀찮고. 메인화면이 pop되는거라 문제되기도할듯
// dispose 그냥 버려~ 아니면. 그거있잖아 맞다
// 화면 넘어갈때 dispose, 돌아올떄 초기화 하면되고. mount였나 -> 아님 걍 null일때 초기화하는식

// ★ 끝나도 뒤로 못 감. 걍 완료 안내만 하고 끝!
// 예약 프로그램/컴퓨터 종료 버튼을 넣으면 ㄱㅊ겠네 (GPT 참고) -> 테스트 해보고 오래 걸리면 그렇게해
//   -> (비)정상 완료 시 작업
// -> 근데 중간중간 에러 게시글 / 인터넷 에러 / 파일명 중복 / 용량 에러 어쩔지 -> 에러로 종료돼도 종료
// -> 음.. .근데 cpp파일 건드렸다가 낭패볼거같아서.. 그냥 그거까진 말래요 ㅡㅜㅡ
class SavingScreen extends StatefulWidget {
  final int startPage;
  final int? endPage;
  final String userCode;

  // final bool bViewCnt;
  // final bool bLikeCnt;
  // final bool bDislikeCnt;
  // final bool bCommentCnt;
  // final bool bBoardName;
  final bool bComment;
  final bool bImage;

  SavingScreen({
    required this.startPage,
    this.endPage,
    required this.userCode,
    this.bComment = true,
    this.bImage = false,
  });

  @override
  _SavingScreenState createState() => _SavingScreenState();
}

class _SavingScreenState extends State<SavingScreen>
{
  int nowPostPage = 1;  // init에서 설정한 startPage로 초기화
  // 10숫자(묶음x)마다 txt 리필 -> 입력받음 (기본값 = 1) = 글 240개
  // (ex, 1페이지부터 (1~10) / 101페이지부터 (101~110) / 5페이지부터 (5~10)) = 난 860개 txt파일
  int nowPostNumInPage = 0;
  int get nowPostNum => nowPostPage * PostListModel.kMaxListSize + nowPostNumInPage;

  int nowCommentPage = 1;
  int nowCommentNum = 0;
  int nowCommentNumInPage = 0;

  int nowReplyPage = 1;
  int nowReplyNum = 0;
  int nowReplyNumInPage = 0;

  int commentReplyCnt = 0;
  // 표시+이미지에 사용되는 댓글/답글 번호는 댓글/답글의 누적
  // (getter로 못함. reply는 나오기도 하기때문에! 누적을 실시간으로 같이 시켜야함)

  int recentMyLevel = 0; // 내 레벨은 변경시에만 출력

  ////////////////////////
  final fileHandler = FileHandler();

  int currentPost = 0;
  int totalPosts = 0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nowPostPage = widget.startPage;
    totalPosts = widget.endPage ?? 8000; // 설정된 endPage가 없으면 기본값 8000
    startSaving();
  }

  Future<void> startSaving() async {
    setState(() {
      isSaving = true;
    });

    for (int i = widget.startPage; i <= totalPosts; i++) {
      await saveImage(i);
      setState(() {
        currentPost = i;
      });
    }

    setState(() {
      isSaving = false;
    });
  }

  Future<void> saveImage(int index) async {
    String url = 'https://testPost.com/$index.jpg';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$index.jpg');
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to load image $index');
      }
    } catch (e) {
      debugPrint('Error downloading image $index: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Saving Status'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSaving
                  ? '저장 중: $currentPost / $totalPosts'
                  : '저장이 완료되었습니다!',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: currentPost / totalPosts,
              minHeight: 10,
            ),
          ],
        ),
      ),
    );
  }
}

//   // 파일에 문자열 추가
//   await fileHandler.appendToFile('This is a new line of text.');
//   await fileHandler.appendToFile('This is another line of text.');
//
//   // 파일 내용 읽기
//   String fileContent = await fileHandler.readFile();
//   print(fileContent);

class FileHandler {
  // 파일 경로 가져오기
  // ex, 1~10페, 92~100페
  Future<String> getFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName.txt';  // 파일 이름을 지정
  }

  // 파일에 문자열 추가
  Future<void> appendToFile(String fileName, String text) async {
    final filePath = await getFilePath(fileName);
    final file = File(filePath);

    // 파일이 존재하지 않으면 생성 후 쓰기
    if (!(await file.exists())) {
      await file.create(recursive: true);
    }

    // 파일 끝에 문자열 추가
    await file.writeAsString(
      '$text\n',
      mode: FileMode.append, // append 모드로 설정
      flush: true, // 데이터를 즉시 디스크에 기록
    );
  }

  // 파일 읽기 (저장된 내용 확인용)
  Future<String> readFile(String fileName) async {
    try {
      final filePath = await getFilePath(fileName);
      final file = File(filePath);
      return await file.readAsString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }
}