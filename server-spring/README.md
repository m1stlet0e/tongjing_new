# 同镜 API（Spring Boot）

与根目录 `server`（Express）相同的 **PostgreSQL 库** 与 **`/api/v1/*` 契约**，可二选一运行。

## 要求

- JDK 17+
- Maven 3.9+
- 已存在的业务表（与原 Supabase / Drizzle 迁移一致）

## 配置

通过环境变量或 `application.yml` 覆盖：

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | JDBC，如 `jdbc:postgresql://host:5432/postgres` |
| `DATABASE_USER` / `DATABASE_PASSWORD` | 数据库账号 |
| `COZE_BUCKET_ENDPOINT_URL` | S3 兼容 Endpoint |
| `COZE_BUCKET_NAME` | 桶名 |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | 可选；不填则走默认凭证链 |
| `S3_REGION` | 默认 `cn-beijing` |
| `PORT` | 默认 `9091` |

## Supabase（已预置项目连接）

仓库内 profile **`supabase`** 默认使用 **Transaction Pooler**（`6543`），与 Supabase 控制台「Connect」中的 Pooler 一致；需要直连时可覆盖 `DATABASE_URL` / `DATABASE_USER`。

- Pooler 示例：`aws-1-ap-southeast-1.pooler.supabase.com:6543`，用户 `postgres.<project-ref>`
- JDBC 已带 `sslmode=require`

**数据库密码（任选其一）：**

- 环境变量 `DATABASE_PASSWORD` 或 `SUPABASE_DB_PASSWORD`
- 将 `local-supabase.properties.example` 复制为 **`server-spring/local-supabase.properties`**，填写 `local.supabase.password=`（该文件已 `.gitignore`，勿提交）

**IntelliJ**：运行配置选 **`TongjingServerApplication (Supabase)`**（Active profiles：`supabase`），在 **Environment variables** 里设置 `DATABASE_PASSWORD`，或使用上面的 `local-supabase.properties`（工作目录需为 `server-spring`，与 IDEA 默认一致）。

**端口 9091 已被占用**：在运行配置里增加 `PORT=9092`，或结束占用进程：`lsof -i :9091` 后 `kill <PID>`。

**命令行：**

```bash
cd server-spring
export SPRING_PROFILES_ACTIVE=supabase
export DATABASE_PASSWORD='你的Supabase数据库密码'
mvn spring-boot:run
```

若改用 Transaction Pooler，请以 Supabase Connect 页面为准，显式覆盖：

- `DATABASE_URL=jdbc:postgresql://<pooler-host>:6543/postgres?sslmode=require`
- `DATABASE_USER=<pooler-username>`

### 首次初始化 Supabase 空库（自动建表）

如果你的 Supabase 项目是新建且显示 `No migrations`，可用一次性 profile 自动建表：

```bash
cd server-spring
export SPRING_PROFILES_ACTIVE=supabase-init
export DATABASE_PASSWORD='你的Supabase数据库密码'
mvn spring-boot:run
```

启动成功后即可停止，然后切回常规 profile：`supabase`。

IntelliJ 可直接选运行配置：`TongjingServerApplication (Supabase Init)`，填入 `DATABASE_PASSWORD` 后运行一次。

## 本机 PostgreSQL（macOS / Homebrew）

未安装时：

```bash
brew install postgresql@16
echo 'export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
brew services start postgresql@16
```

创建应用库（库名与 `application-local.yml` 默认一致）：

```bash
createdb tongjing
```

表结构需与现有 Drizzle / Supabase 迁移一致（本服务 `ddl-auto: none`，不会自动建表）。

**本机 profile**：默认 JDBC 用户名为当前系统用户、密码为空（与常见 Homebrew 本机 `trust` 一致）；若你使用 `postgres` 用户与密码，请设置环境变量覆盖。

```bash
cd server-spring
export SPRING_PROFILES_ACTIVE=local
# 可选：export DATABASE_USER=postgres DATABASE_PASSWORD=你的密码
mvn spring-boot:run
```

IntelliJ：Run Configuration 里增加环境变量 `SPRING_PROFILES_ACTIVE=local`，按需设置 `DATABASE_USER` / `DATABASE_PASSWORD`。

## 运行（通用）

```bash
cd server-spring
export DATABASE_URL=jdbc:postgresql://...
export DATABASE_USER=...
export DATABASE_PASSWORD=...
mvn spring-boot:run
```

### 强制指定 profile / 配置文件

避免 IntelliJ 或命令行误用 `default`，可显式指定：

```bash
# 指定 profile（推荐）
mvn spring-boot:run -Dspring-boot.run.profiles=supabase

# 或 JVM 参数方式
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Dspring.profiles.active=supabase"

# 指定外部配置文件（可选）
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Dspring.config.location=file:./src/main/resources/application.yml,file:./src/main/resources/application-supabase.yml"
```

生产打包：

```bash
mvn -q package
java -jar target/server-spring-1.0.0.jar
```

前端将 `EXPO_PUBLIC_BACKEND_BASE_URL` / Flutter `API_BASE_URL` 指向本服务地址即可。

## 与 Express 的差异说明

- 列表类接口的分页 **`total`** 在部分接口上与旧版统计口径可能略有不同（Spring 版对筛选结果使用一致计数）。
- 地图「按地点搜索」当前为内存过滤实现，数据量极大时可改为数据库 `ILIKE` 查询。
