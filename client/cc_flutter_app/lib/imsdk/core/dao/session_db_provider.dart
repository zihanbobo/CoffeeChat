import 'dart:convert';

import 'package:cc_flutter_app/imsdk/core/dao/base_db_provider.dart';
import 'package:cc_flutter_app/imsdk/core/model/model.dart';
import 'package:cc_flutter_app/imsdk/proto/CIM.Def.pb.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:fixnum/fixnum.dart';

class SessionDbProvider extends BaseDbProvider {
  ///表名
  final String name = 'im_session';
  final String columnSessionId = "session_id";
  final String columnSessionType = "session_type";
  final String columnSessionStatus = "session_status";
  final String columnUpdatedTime = "updated_time";
  final String columnLatestClientMsgId = "latest_client_msg_id";
  final String columnLatestServerMsgId = "latest_server_msg_id";
  final String columnLatestMsgData = "latest_msg_data";
  final String columnLatestMsgFromId = "latest_msg_from_id";
  final String columnLatestMsgStatus = "latest_msg_status";
  final String columnUnreadCount = "unread_count";

  SessionDbProvider();

  @override
  tableName() {
    return name;
  }

  @override
  createTableString() {
    return '''
        create table $name (
        id integer primary key AUTOINCREMENT,
        $columnSessionId text not null,
        $columnSessionType integer not null,
        $columnSessionStatus integer not null,
        $columnUpdatedTime integer not null,
        $columnLatestClientMsgId text not null,
        $columnLatestServerMsgId integer default 0,
        $columnLatestMsgData text default null,
        $columnLatestMsgFromId text default null,
        $columnLatestMsgStatus integer default 0,
        $columnUnreadCount integer default 0,
        reserve1 text default null,
        reserve2 integer default null,
        reserve3 integer default null)
      ''';
  }

  ///查询数据库
  Future<List<Map<String, dynamic>>> _getPersonProvider(Database db, int sessionId) async {
    List<Map<String, dynamic>> maps = await db.rawQuery("select * from $name where $columnSessionId = $sessionId");
    return maps;
  }

  Future<int> existSession(int sessionId, int sessionType) async {
    Database database = await getDataBase();
    List<Map<String, dynamic>> maps = await database
        .rawQuery("select count(1) from $name where $columnSessionId=$sessionId and $columnSessionType=$sessionType");
    return maps[0]["count(1)"];
  }

  ///插入到数据库
  Future insert(SessionModel session) async {
    Database db = await getDataBase();
    var userProvider = await _getPersonProvider(db, session.sessionId);
    if (userProvider != null && userProvider.length > 0) {
      print("alread exist session with sessionId:${session.sessionId}");
      return null;
    }
    var sql = '''
    insert into $name ($columnSessionId,$columnSessionType,$columnSessionStatus,
    $columnUpdatedTime,$columnLatestClientMsgId,$columnLatestServerMsgId,
    $columnLatestMsgData,$columnLatestMsgFromId,$columnLatestMsgStatus,$columnUnreadCount) 
    values (?,?,?,?,?,?,?,?,?,?)
    ''';
    int result = await db.rawInsert(sql, [
      session.sessionId,
      session.sessionType.value,
      session.sessionStatus.value,
      session.updatedTime,
      session.latestMsg.clientMsgId,
      session.latestMsg.serverMsgId,
      session.latestMsg.msgData,
      session.latestMsg.fromUserId,
      session.latestMsg.msgStatus.value,
      session.unreadCnt,
    ]);
    //print(result);
  }

  ///更新数据库
  Future<void> update(int sessionId, int sessionType, SessionModel session) async {
    Database database = await getDataBase();
    var sql = '''
    update $name set $columnSessionStatus = ?,
    $columnUpdatedTime = ?,$columnLatestClientMsgId = ?,$columnLatestServerMsgId = ?,
    $columnLatestMsgData = ?,$columnLatestMsgFromId = ?,$columnLatestMsgStatus = ?,
    $columnUnreadCount = ? where $columnSessionId = ? and $columnSessionType = ?
    ''';
    int result = await database.rawUpdate(sql, [
      session.sessionStatus.value,
      session.updatedTime,
      session.latestMsg.clientMsgId,
      session.latestMsg.serverMsgId,
      session.latestMsg.msgData,
      session.latestMsg.fromUserId,
      session.latestMsg.msgStatus.value,
      session.unreadCnt,
      session.sessionId,
      session.sessionType.value
    ]);
    //print(result);
  }

  Future<void> updateUnreadCount(int sessionId, int sessionType) async {}

  /// 获取所有会话
  Future<List<SessionModel>> getAllSession() async {
    Database db = await getDataBase();
    //List<Map<String, dynamic>> maps = await db.rawQuery("select * from $name where session_status != 1");
    List<Map<String, dynamic>> maps = await db.rawQuery("select * from $name order by $columnUpdatedTime desc");
    if (maps.length > 0) {
      List<SessionModel> list = new List<SessionModel>();
      for (var i = 0; i < maps.length; i++) {
        CIMContactSessionInfo sessionInfo = new CIMContactSessionInfo();
        sessionInfo.sessionId = Int64(int.parse(maps[i][columnSessionId])); // text
        // 会话类型
        sessionInfo.sessionType = CIMSessionType.valueOf(maps[i][columnSessionType]);
        sessionInfo.sessionStatus = CIMSessionStatusType.valueOf(maps[i][columnSessionStatus]);
        sessionInfo.updatedTime = maps[i][columnUpdatedTime];
        sessionInfo.unreadCnt = maps[i][columnUnreadCount];

        sessionInfo.msgId = maps[i][columnLatestClientMsgId];
        sessionInfo.serverMsgId = Int64(maps[i][columnLatestServerMsgId]);
        sessionInfo.msgTimeStamp = sessionInfo.updatedTime;
        sessionInfo.msgData = utf8.encode(maps[i][columnLatestMsgData]);
        //sessionInfo.msgType =
        sessionInfo.msgFromUserId = Int64(int.parse(maps[i][columnLatestMsgFromId])); // text
        sessionInfo.msgStatus = CIMMsgStatus.valueOf(maps[i][columnLatestMsgStatus]);
        //sessionInfo.msgAttach

        SessionModel model = SessionModel.copyFrom(sessionInfo, maps[i]["session_id"], "");
        list.add(model);
      }
      return list;
    }
    return null;
  }
}