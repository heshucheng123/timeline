# Supabase SQL 初始化脚本

在 Supabase Dashboard → SQL Editor → New Query 中，复制以下全部内容并执行：

```sql
-- ============================================
-- 我的大学成长时间轴 — 数据库初始化
-- ============================================

-- 1. 主状态表：每个用户一行，存储全部应用状态
CREATE TABLE IF NOT EXISTS app_state (
  id          INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  data        JSONB NOT NULL DEFAULT '{}'::jsonb,
  version     INTEGER NOT NULL DEFAULT 1,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- 2. 更新时间自动触发器
CREATE OR REPLACE FUNCTION update_app_state_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS app_state_updated ON app_state;
CREATE TRIGGER app_state_updated
  BEFORE UPDATE ON app_state
  FOR EACH ROW EXECUTE FUNCTION update_app_state_timestamp();

-- 3. 同步日志表（用于调试和冲突追踪）
CREATE TABLE IF NOT EXISTS sync_log (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  version     INTEGER NOT NULL,
  changed_at  TIMESTAMPTZ DEFAULT NOW(),
  changed_by  TEXT
);

-- 4. 索引
CREATE INDEX IF NOT EXISTS idx_app_state_user ON app_state(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_user_version ON sync_log(user_id, version DESC);

-- ============================================
-- Row Level Security (RLS)
-- ============================================

ALTER TABLE app_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- app_state: 用户只能读写自己的数据
DROP POLICY IF EXISTS "Users can view own state" ON app_state;
CREATE POLICY "Users can view own state"
  ON app_state FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own state" ON app_state;
CREATE POLICY "Users can insert own state"
  ON app_state FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own state" ON app_state;
CREATE POLICY "Users can update own state"
  ON app_state FOR UPDATE
  USING (auth.uid() = user_id);

-- sync_log: 同上
DROP POLICY IF EXISTS "Users can view own sync log" ON sync_log;
CREATE POLICY "Users can view own sync log"
  ON sync_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own sync log" ON sync_log;
CREATE POLICY "Users can insert own sync log"
  ON sync_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- Realtime 配置
-- ============================================
-- 执行完以上 SQL 后，手动操作：
-- 1. Supabase Dashboard → Database → Replication
-- 2. 开启 app_state 表的 Realtime 订阅
-- 3. 开启 sync_log 表的 Realtime 订阅

-- ============================================
-- Auth 配置（手动操作）
-- ============================================
-- 1. Authentication → Settings
-- 2. 关闭 "Enable email confirmations"（个人自用不需要邮箱验证）
-- 3. Authentication → Users → Add User
-- 4. 创建你的账号
```

## 执行步骤

1. 打开 https://supabase.com/dashboard
2. 选择你的项目 `mdoiahwjhgomospwdaiu`
3. 左侧菜单 → SQL Editor
4. 点击 "New query"
5. 粘贴以上全部 SQL
6. 点击 "Run" 执行
7. 手动开启 Realtime（见 SQL 末尾说明）
8. 手动创建 Auth 用户
