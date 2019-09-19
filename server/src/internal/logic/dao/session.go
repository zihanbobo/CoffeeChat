package dao

import (
	"fmt"
	"github.com/CoffeeChat/server/src/api/cim"
	"github.com/CoffeeChat/server/src/internal/logic/model"
	"github.com/CoffeeChat/server/src/pkg/db"
	"github.com/CoffeeChat/server/src/pkg/def"
	"github.com/CoffeeChat/server/src/pkg/logger"
	"time"
)

const kSessionTableName = "im_session"

type TblSession struct {
}

var DefaultTblSession = &TblSession{}

func (t *TblSession) Get(userId uint64, peerId uint64) *model.SessionModel {
	session := db.DefaultManager.GetDBSlave()
	if session != nil {
		sql := fmt.Sprintf("select id,user_id,peer_id,sessoin_type,session_status,"+
			"is_robot_session,created,updated from %s where user_id=%d and peer_id=%d", kSessionTableName, userId, peerId)
		row := session.QueryRow(sql)

		model := &model.SessionModel{}
		err := row.Scan(model.Id, model.UserId, model.PeerId, model.SessionType, model.SessionStatus, model.IsRobotSession, model.Created, model.Updated)
		if err == nil {
			return model
		} else {
			logger.Sugar.Error("no result for sql:", sql)
		}

	} else {
		logger.Sugar.Error("no db connect for slave")
	}
	return nil
}

/*
 * 添加一个用户和用户的会话记录
 * 注：以事物的方式添加双向关系,a->b,b->a
 */
func (t *TblSession) AddUserSession(userId uint64, peerId uint64, sessionType cim.CIMSessionType, sessionStatus cim.CIMSessionStatusType,
	isRobotSession bool) error {
	session := db.DefaultManager.GetDbMaster()
	if session != nil {
		robotSession := 0
		if isRobotSession {
			robotSession = 1
		}
		timeStamp := time.Now().Unix()

		// begin transaction
		err := session.Begin()
		if err != nil {
			logger.Sugar.Error("session begin error:", err.Error())
			return err
		}

		result := false
		// insert a->b
		sql := fmt.Sprintf("insert into %s(user_id,peer_id,sessoin_type,session_status,"+
			"is_robot_session,created,updated) values(%d,%d,%d,%d,%d,%d,%d)",
			kSessionTableName, userId, peerId, int(sessionType), int(sessionStatus), robotSession, timeStamp, timeStamp)
		r, err := session.Exec(sql)
		if err != nil {
			logger.Sugar.Errorf("Exec error:%s,sql:%s", err.Error(), sql)
		} else if _, err := r.RowsAffected(); err != nil {
			logger.Sugar.Errorf("Exec error:%s,sql:%s", err.Error(), sql)
		} else {
			result = true
		}

		// insert b->a
		if result {
			result = false
			sql = fmt.Sprintf("insert into %s(user_id,peer_id,sessoin_type,session_status,"+
				"is_robot_session,created,updated) values(%d,%d,%d,%d,%d,%d,%d)",
				kSessionTableName, peerId, userId, int(sessionType), int(sessionStatus), robotSession, timeStamp, timeStamp)
			r, err = session.Exec(sql)
			if err != nil {
				logger.Sugar.Errorf("Exec error:%s,sql:%s", err.Error(), sql)
			} else if _, err := r.RowsAffected(); err != nil {
				logger.Sugar.Errorf("Exec error:%s,sql:%s", err.Error(), sql)
			} else {
				result = true
			}
		}

		// commit transaction
		if result {
			err := session.Commit()
			if err != nil {
				logger.Sugar.Errorf("session commit error:%s,sql:%s", err.Error(), sql)
			} else {
				result = true
			}
		}

		// if error, then rollback transaction
		if !result {
			err := session.Rollback()
			if err != nil {
				logger.Sugar.Errorf("session rollback error:%s,sql:%s", err.Error(), sql)
				return err
			}
		}
	} else {
		logger.Sugar.Error("no db connect for master")
	}
	return def.DefaultError
}

// 添加用户和群的会话关系
func (t *TblSession) AddGroupSession(userId uint64, groupId uint64, sessionType cim.CIMSessionType, sessionStatus cim.CIMSessionStatusType,
	isRobotSession bool) error {
	session := db.DefaultManager.GetDbMaster()
	if session != nil {
		robotSession := 0
		if isRobotSession {
			robotSession = 1
		}
		timeStamp := time.Now().Unix()

		sql := fmt.Sprintf("insert into %s(user_id,peer_id,sessoin_type,session_status,"+
			"is_robot_session,created,updated) values(%d,%d,%d,%d,%d,%d,%d)",
			kSessionTableName, userId, groupId, int(sessionType), int(sessionStatus), robotSession, timeStamp, timeStamp)
		r, err := session.Exec(sql)
		if err != nil {
			logger.Sugar.Errorf("sql Exec error:%s,sql:%s", err.Error(), sql)
		} else if _, err := r.RowsAffected(); err != nil {
			logger.Sugar.Errorf("sql Exec error:%s,sql:%s", err.Error(), sql)
		} else {
			return nil // success
		}
	} else {
		logger.Sugar.Error("no db connect for master")
	}
	return def.DefaultError
}

// 更新会话最后修改时间
func (t *TblSession) UpdateUpdated(id int, updated int) error {
	session := db.DefaultManager.GetDbMaster()
	if session != nil {
		sql := fmt.Sprintf("update %s set updated=%d where id=%d", kSessionTableName, updated, id)
		r, err := session.Exec(sql)
		if err != nil {
			logger.Sugar.Error("sql Exec error:", err.Error())
		} else {
			row, err := r.RowsAffected()
			if err != nil {
				return err
			} else {
				if row != 1 {
					logger.Sugar.Warn("update success,but row num != 1 for sql:", sql)
				}
				// success
				return nil
			}
		}
	} else {
		logger.Sugar.Error("no db connect for master")
	}
	return def.DefaultError
}
