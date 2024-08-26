import 'dart:convert';  // JSON 데이터를 파싱하기 위해 필요
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
  int? endPage;
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
  final fileHandler = FileHandler();

  bool isSaving = false;
  String? errorStr;

  @override
  void initState() {
    super.initState();
    postPageIdx = widget.startPage;
    startSaving();
  }

  int postPageIdx = 1;  // init에서 설정한 startPage로 초기화
  // 10숫자(묶음x)마다 txt 리필 -> 입력받음 (기본값 = 1) = 글 240개
  // (ex, 1페이지부터 (1~10) / 101페이지부터 (101~110) / 5페이지부터 (5~10)) = 난 860개 txt파일
  int postIdxInPage = 0;
  int get postCnt => (postPageIdx-1) * PostListModel.kMaxListSize + postIdxInPage;

  int cmtPageIdx = 1;
  int cmtIdxInPage = 0;

  int replyPageIdx = 1;   // 역순 아님
  int replyIdxInPage = 0;    // 역순 (4~0)

  int cmtReplyCnt = 0;
  // -> 댓글/답글 번호는 댓글/답글의 ★누적 (txt 출력 + 이미지 번호에 사용됨)
  // -> 답글 목록은 계속 바뀌니까 getter로 못함! 누적을 시켜야함!

  int recentMyLevel = 0; // 내 레벨은 변경시에만 출력

  PostListModel? postList;
  PostModel? post;
  CommentListModel? cmtList;
  CommentListModel? replyList;

  Future<void> startSaving() async
  {
    setState(() => isSaving = true);

    while (true)
    {
      // 1. 불러옴
      try {
        postList = await fetchModel<PostListModel>(
          url: PostListModel.getJsonUrl(widget.userCode, postPageIdx),
          fromJson: (json) => PostListModel.fromJson(json),
        );
      }
      // 1-1. 로딩을 못 했거나
      catch (e) {
        setState(() => errorStr = e.toString());
        return;
      }
      // 1-2. total이 0일 경우 에러 처리
      if (postList?.total == 0)
      {
        setState(() => errorStr = '잘못된 페이지 참조');
        return;
      }
      // 2. (최초 1회) endPage 미설정 시 초기화
      if (widget.endPage == null)
      {
        setState(() => widget.endPage = (postList!.total / PostListModel.kMaxListSize).ceil());
      }

      // 3. 본격 txt에 게시글 저장 작업

      // n페 출력

      for (postIdxInPage = 0;
           postIdxInPage < postList!.list.length;
           postIdxInPage++)
      {
        // - 텍스트 저장

        // ※ 번호. [기타] 제목

        // 레벨 / 201뷰 / 창작 / 날짜-시간 / 댓5 / 5♥ (12b-3p) / 설문 / 미디어 (n개. 1개는 표기X)

        // - 이미지&영상 저장

        // -> article_id 앞 2글자가 TR일 때만 previewUrl 사용하고
        //    외엔 전부 postModel 참조

        // (영상 youtube.com/embed/1234) * n
        // -> 사진 옵션 관계없이 movie_yn이 Y라면 postModel 참조 ?? -> ?? 미디어로 통합하기로 했지? 다시 체크

        // 본문

        // string을 받는게 아니라. 제공해주면 txt에 쓰는애면 될듯?
        await exportToTxt(i);

        // 댓글을 체크했고, 댓글이 있을 경우 처리
        if (widget.bComment &&
            postList!.list[postIdxInPage].commentScore >= 1) exportComment();
      }

      // 99. 한 페이지 완료 시 작업
      setState(() => postPageIdx++);
      postIdxInPage = 0;

      if (postPageIdx-1 == widget.endPage) break;   // or postList.nextYn == 'N'으로 대체 가능 (필드 추가 必)
    }

    setState(() => isSaving = false);
  }

  void exportComment()
  {
    cmtPageIdx = 1;
    cmtReplyCnt = 0;

    while (true)
    {
      for (cmtIdxInPage = 0;
           cmtIdxInPage < cmtList!.list.length;
           cmtIdxInPage++, cmtReplyCnt++)
      {

        // 답글이 있을 경우 처리
        if (cmtList!.list[cmtIdxInPage].commentScore >= 1) exportReply();
      }

      if (cmtList!.nextYn == 'N') return;

      cmtPageIdx++;
    }
  }

  void exportReply()
  {
    replyPageIdx = 1;

    while (true)
    {
      try {
        replyList = await fetchModel<CommentListModel>(
          url: CommentListModel.getReplyJsonUrl(cmtList!.list[cmtIdxInPage].commentId, replyPageIdx),
          fromJson: (json) => CommentListModel.fromJson(json),
        );
      }
      catch (e) {
        setState(() => errorStr = e.toString());
        return;
      }

      for (replyIdxInPage = replyList!.list.length -1; // ★역순
           replyIdxInPage >= 0;
           replyIdxInPage--, cmtReplyCnt++)
      {
        // -> 번호) 답글
      }

      if (replyList!.nextYn == 'N') return;

      replyPageIdx++;
    }
  }

  Future<T> fetchModel<T>({
    required String url,
    required T Function(Map<String, dynamic>) fromJson,
  }) async
  {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // 서버가 OK 응답을 반환하면 JSON을 파싱합니다.
      return fromJson(json.decode(response.body));
    } else {
      // 서버가 OK 응답을 반환하지 않으면 예외를 던집니다.
      throw Exception('페이지 로딩 실패');
    }
  }

  Future<void> exportToTxt(int index) async
  {
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

  // ★글이 아닌 페이지 단위로 표시
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('테런 게시글 저장기 (by 꾸밈)'),
      ),
      body: errorStr != null ? Center(child: Text('에러 : $errorStr', style: const TextStyle(fontSize: 24))) :
        widget.endPage == null ? const Center(child: CircularProgressIndicator()) :
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isSaving
                    ? '저장 중: $cmtPageIdx / ${widget.endPage} 페이지'
                    : '저장이 완료되었습니다!',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: cmtPageIdx / widget.endPage!,
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