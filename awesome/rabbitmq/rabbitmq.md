## RabbitMQ

### introduce

1. 简介:

   - RabbitMQ 开源消息队列系统, 是 `AMQP(Advanced Message Queuing Protocol)` 的标准实现, 用 erlang 语言开发.

2. 优点:

   - RabbitMQ 性能好、时效性、集群和负载部署; 适合较大规模的分布式系统.

3. 组成元素

   1. Exchange: 接收相应的消息并且绑定到指定的队列

      - 如果不指定 Exchange 的话, RabbitMQ 默认使用[AMQP default], `需要将 routing key 等于 queue name 相同`

   2. name/type:

      - fanout[效率最好, 不需要 routing key, routing key 如何设置都可以]
      - direct
      - topic[#一个或多个, *一个]
      - headers

   3. Auto Delete:

      - 当最后一个 Binding 到 Exchange 的 Queue 删除之后, 自动删除该 Exchange

   4. Binding:

      - Exchange 和 Queue 之间的连接关系，Exchange 之间也可以 Binding

   5. Queue:

      - 实际物理上存储消息的

   6. Durability: 是否持久化

      - Durable: 是, 即使服务器重启, 这个队列也不会消失
      - Transient: 否

   7. Exclusive:

      - 这个 queue 只能由一个 exchange 监听 `restricted to this connection`, `使用场景: 顺序消费`
      - 针对连接可见，只要是当前 connection 下的信道都可以访问
      - 一旦该队列被声明，其他连接无法声明相同名称的排他队列。
      - 队列即使显示声明为 durable，连接断开时（注意不是信道断开）也会被自动删除。

   8. Message:

      - properties[有消息优先级、延迟等特性]
      - Body[Payload 消息内容]组成
      - 还有 content_type
      - content_encoding
      - priority
      - correlation_id
      - reply_to
      - expiration
      - message_id 等属性

   9. ack

      - autoACK
      - 手动签收

   10. 生产者
   11. 消费者
   12. virtual hosts: 虚拟主机[数据库]

4. 工作流程

   ![avatar](/static/image/mq/rabbitmq-model.png)
   ![avatar](/static/image/mq/rabbitmq.png)

5. [Rabbitmq, amqp Intro - Messaging Patterns](https://www.slideshare.net/javierarilos/rabbitmq-intromsgingpatterns)

   - Search title in bing.com and open with cached page if cannot access slideshare

6. [AMQP 0-9-1 Model Explained](https://www.rabbitmq.com/tutorials/amqp-concepts.html)

7. 交换机: 接收相应的消息并且绑定到指定的队列: Direct、topic、headers、Fanout

   - 如果不指定 Exchange 的话, RabbitMQ 默认使用(AMQP default); 注意一下, 会将 routing key 等于 queue name 相同
   - Direct 默认的交换机模式[最简单]: 即 发送者发送消息时指定的 `key` 与创建队列时指定的 `BindingKey` 一样时, 消息将会被发送到该消息队列中.
   - [可以模糊匹配]topic 转发信息主要是依据 `通配符`, 发送者发送消息时指定的 `key` 与 `队列和交换机的绑定时` 使用的 `依据模式(通配符+字符串)` 一样时, 消息将会被发送到该消息队列中.
     - `#匹配 一个或多个单词，\*匹配一个单词`
   - headers 是根据 `一个规则进行匹配`, 而发送消息的时候 `指定的一组键值对规则` 与 在消息队列和交换机绑定的时候会指定 `一组键值对规则` 匹配时, 消息会被发送到匹配的消息队列中.
   - Fanout 是 `路由广播` 的形式, 将会把消息发给绑定它的全部队列, 即便设置了 key, 也会被忽略 `[相当于发布订阅模式]`.

### install on linux os

1. origin install

   ```shell
   # 1. 首先必须要有Erlang环境支持
   apt-get install erlang-nox

   # 2. 添加公钥
   sudo wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -
   apt-get update

   # 3. 安装 RabbitMQ
   apt-get install rabbitmq-server  #安装成功自动启动

   # 4. 查看 RabbitMQ 状态
   systemctl status rabbitmq-server

   # 5. web 端可视化
   rabbitmq-plugins enable rabbitmq_management   # 启用插件
   service rabbitmq-server restart # 重启

   # 6. 添加用户
   rabbitmqctl list_users
   rabbitmqctl add_user admin yourpassword   # 增加普通用户
   rabbitmqctl set_user_tags admin administrator    # 给普通用户分配管理员角色

   # 7. 管理
   service rabbitmq-server start    # 启动
   service rabbitmq-server stop     # 停止
   service rabbitmq-server restart  # 重启
   ```

2. in docker

   ```yml
   rabbitmq:
     image: registry.cn-shanghai.aliyuncs.com/alice52/dev-rabbitmq:20200417.713eb17
     restart: 'on-failure:3'
     container_name: dev-rabbitmq
     hostname: rabbit
     ports:
       - 15672:15672
       - 5672:5672
     volumes:
       - /root/rabbitmq/data:/var/lib/rabbitmq
       - /root/rabbitmq/logs:/var/log/rabbitmq
     logging:
       driver: 'json-file'
       options:
         max-size: '20M'
         max-file: '10'
     environment:
       RABBITMQ_DEFAULT_VHOST: /
       RABBITMQ_DEFAULT_USER: guest
       RABBITMQ_DEFAULT_PASS: guest
       TZ: Asia/Shanghai
   ```

### RabbitMQ 模式

1. 单一模式: 单实例服务
2. 普通模式: 默认的集群模式

   - 在没有 `policy` 时, QUEUE 会默认创建集群:

     1. 消息实体只存在与其中的节点, A、B 两个节点仅具有相同的元数据[队列结构], 但是队列的元数据只有一份在创建该队列的节点上; 当 A 节点宕机之后可以去 B 节点查看; 但是声明的 exchange 还在.
     2. msg 进入 A 节点, consumer 却从 B 节点获取: RabbitMQ 会临时在 A、B 间进行消息传输, 把 A 中的消息实体取出并经过 B 发送给 consumer
     3. consumer 应尽量连接每一个节点, 从中取消息
     4. 同一个逻辑队列, 要在多个节点建立物理 Queue

   - 缺点:
     1. A 节点故障后, B 节点无法取到 A 节点中还未消费的消息实体
     2. 做了消息持久化, 那么得等 A 节点恢复, 然后才可被消费；
     3. 如果没有持久化的话, 队列数据就丢失了

3. 镜像模式: 把需要的队列做成镜像队列, 存在于多个节点, 属于 RabbitMQ 的 HA 方案

   - 消息实体会主动在镜像节点间同步, 而不是在 consumer 取数据时临时拉取
   - policy 进行配置: ha-mode、ha-params

     | ha-mode | ha-params | introduce                                                                            |
     | :-----: | :-------: | :----------------------------------------------------------------------------------- |
     |   all   |  absent   | 镜像到集群内的所有节点                                                               |
     | exactly |   count   | 镜像到集群内指定数量的节点:                                                          |
     |         |           | 集群内该队列的数量少于这个数 count, 则镜像到所有节点;                                |
     |         |           | 集群内该队列的数量多于这个数 count, 且包含一个镜像的停止节点, 则不会载其他节点上镜像 |
     |  nodes  | node name | 镜像到指定节点. 该指定节点不能存在与集群中时报错;                                    |
     |         |           | 如果没有指定节点, 则队列会被镜像到发起声明的客户端所连接的节点上.                    |

   - 缺点
     1. 降低性能
     2. 消耗带宽

### 安全可靠投递

1. 可能出现消息丢失的情况

   - producer 消息发送到 Broker 过程中丢失: `请求确认机制 + **异步发送时要回调方法里进行检查**` 或者 `~~开启MQ的事务回滚: 消耗资源~~`
   - Broker 接收到 Message 暂存到内存, 没来的及消费, broker 挂了: `持久化: 消息写入磁盘后 ack`
     - 声明 Queue 设置持久化, 保证 Broker 持久化 Queue 的元数据, 但是不会持久化 Queue 里面的消息
     - 将 Message 的 deliveryMode 设置为 2, 只有 Message 持久化到磁盘之后才会发送通知 Producer ack
   - 消费时异常: `只有成功消费才手动给 broker ack`

2. 生产端

   - 保证消息的成功发出
   - 保证 MQ 节点的成功接收
   - 发送端收到 MQ 节点[Broker]的确认应答
   - 完善的消息补偿机制

3. 解决方案: 消息落库, confim 对消息状态进行变更[不能高并发: 对数据库操作太多]

   // TODO: 消息又被消费者消费嘛, 再入库之前?
   ![avatar](/static/image/mq/rabbitmq-send.png)

   - workflow

     1. 业务数据和消息都进行落库
     2. 生产端发送 message 给 Broker
     3. Broker 给 Confirm 响应返回生产端
     4. 接收到 confirm, 对 message 状态更改
     5. 分布式定时任务获取消息的状态
     6. 如果消息不能成功投递, 重新进行发送, 记录重发次数
     7. 当重发 3 次之后, 将状态修改, 只能人工进行干预

4. 解决方案: 消息的延迟投递, 做二次确认, 回调检查[适合高并发环境, 减少写库的次数]

   // TODO: 消息又被消费者消费嘛, 再入库之前?
   ![avatar](/static/image/mq/rabbitmq-send-delay.png)

   - workflow: 减少了一次数据库的交互
     1. 上游服务首先将业务代码, 发送 message 给 Broker
     2. 上游服务接着发送第二个延迟确认消息
     3. 下游服务监听消息进行消费
     4. 下游服务发送确认消息, 这里不是 confirm 机制, 而是一条新的消息
     5. 通过回调服务监听这个 confirm 消息，然后把消息进行入库
     6. 回调服务检查到延迟确认消息: 会在数据库查询是否有这条消息
     7. 如果没有查到这条消息，回调服务通过 RPC 给一个重新发送命令到上游系统

### MQ 幂等性消费

1. 出现非幂等性的情况

   - 可靠性消息投递机制: consumer 回复 confirm 出现网络闪断, producer 没有收到 ack
   - MQ Broker 与消费端传输消息的过程出现网络抖动
   - 消费端故障或异常

2. 解决方案: 唯一 ID+指纹码

   ![avatar](/static/image/mq/rabbitmq-consumer--same.png)

   - 数据库写入, 利用数据库主键去重, 使用 ID 进行分库分表算法路由, 从单库的幂等性到多库的幂等性
   - 这里唯一 ID 一般就是业务表的主键, 比如商品 ID
   - 指纹码: 每次操作都要生成指纹码, 可以用 `时间戳+业务编号+...` 组成, 目的是保证每次操作都是正常的
   - workflow
     - 需要一个统一 ID 生成服务, 为了保证可靠性, 上游服务也要有个本地 ID 生成服务, 然后发送消息给 Broker
     - 需要 ID 规则路由组件去监听消息, 先入库, 如果入库成功，证明没有重复，然后发给下游，如果发现库里面有了这条消息，就不发给下游

3. 解决方案: 利用 Redis 的原子性实现

   - `redis SETNX`, `INSERT IF NOT EXIST`: 消息就丢在 redis 中

### Message confirmation mechanism

1. 定义: 消息确认

   - 当 Producer 发送消息, 如果 Broker 收到消息, 会回复一个应答[保证可靠性投递]
   - broker 恢复应答, producer 会进入 `handleAck()` 方法

2. For Producer

   - Transaction mechanism(Poor performance)
     - use TxSelect(), set channel to transaction mode
     - use TxCommit(), commit transaction
     - use TxRollback(), roll back transaction
   - Confirm mechanism
     - Common confirm mode
     - Batch confirm mode
     - Asynchronous confirm mode

3. For Consumer

   - Message acknowledgment

### Return 消息机制

1. 作用: Return Listener 用于处理一些不可路由的消息
2. Mandatory 设置为 true, 如果为 false，broker 自动删除该消息

### 消息端限流

1. qos[服务质量保证]: 在非自动确认情况下, 一定数目的消息没有确认, 不进行消费新的消息

   - prefetchSize: 默认 0 表示对单条 message 的大小没有限制
   - global: false[非 channel 级别,consumer 级别]
   - channel.basicConsume 中自动签收一定要设置成 false
   - prefetch_count: 表示一次给几条进行消费, 直到返回 ack, 才能继续给 prefetch_count 条 message

   // TODO:

### 批量消息

### 延时消息

### 消息的顺序消费

1. 简单思路: 一个 CONSUMER, 多个 CONSUMER 依旧无法保证顺序

   - 一个 QUEUE 有且只有一个 CONSUMER
   - 把 MESSAGE 丢进同一个 QUEUE
   - 关闭 autoack
   - 设置 prefetchCount=1, 每次处理一条消息, 且需要手工的 ACK
   - 处理下一条消息

2. practice
   - MESSAGE 同一个队列, 且只有一个 CONSUMER
   - 然后 同意提交[可以合并一个大消息, **`或拆分多个消息`**]，并且所有消息的会话 ID 一致
   - 添加消息属性: **顺序表及的序号、本地顺序消息的 size 属性、进行落库操作**
   - 并行进行发送给自身的延迟消息(带上关键属性: 会话 ID、SIZE)进行后续处理消费
   - 当收到延迟消息后, 根据会话 ID、SIZE 抽取数据库数据进行处理即可
   - 定时轮询补偿机制, 对于异常情况

#### 集群 HA

1. RabbitMQ 集群节点: 内存节点、磁盘节点
   - 投递消息时, 打开了消息的持久化, 那么即使是内存节点, 数据还是安全的放在磁盘
2. 一个 rabbitmq 集群中可以共享 user, vhost, queue, exchange
   - 所有的数据和状态都是必须在所有节点上复制的`[除外:只属于创建它的节点的消息队列]`

### rabbitmqctl

1. cd rabbitmq server locaton, such as: cd `C:\Program Files (x86)\RabbitMQ Server\rabbitmq_server-3.5.1\sbin`
2. run command **`rabbitmqctl -q status`**: view rabbitmq service status information, including memory, hard disk, and version information using erlong
3. run command **`rabbitmqctl list_queues`** to view all queue messages
4. run command **`rabbitmqctl list_consumers`** to view all consumers
5. run command **`./rabbitmq-plugins enable rabbitmq_tracing`** and add trace log file in RabbitMQ Admin Page to view message detail.

## Troubleshooting

### Overview

1. [Troubleshooting Guidance](https://www.rabbitmq.com/troubleshooting.html)

### Crash dump

1. analysis erl_crash.dump: [erl_crashdump_analyzer.sh](https://emacsist.github.io/2016/12/01/rabbitmq%E7%9A%84crash-dump%E6%96%87%E4%BB%B6%E5%88%86%E6%9E%90/)

2. **Log**: in velo-qa-app01: **C:\Users\Administrator\AppData\Roaming\RabbitMQ**

   - erl_crash.dump (last shutdown error log)
     - Use git.bash run **./erl_crashdump_analyzer.sh erl_crash.dump** to analysis erl_crash.dump. ([erl_crashdump_analyzer.sh](uploads/f3f138b5a8e31ef67c1a60d1e0bfb615/erl_crashdump_analyzer.sh))
   - rabbit_VELO-QA-APP01.log (contains all runtime logs detail)

---

## 小总结

1. routing key

- publish 会向所有满足条件的 queue 内都放入相关的 message
- simple/work mode: no exchange

  - `publish 时的 ROUTING_KEY 会决定最终这条 message 到哪个 queue. 如果没有 queue 和这个 ROUTING_KEY 做 bind, 则会寻找与 ROUTING_KEY 一样的 queue, 并将消息放入这个 queue`

  ```java
  // 这里会 declare queue,
  channel.queueDeclare(Constants.SIMPLE_QUEUE_NAME, false, false, false, null);
  // 这里有一个默认的规则: .
  channel.basicPublish(Constants.EXCHANGE_DIRECT_NAME, Constants.ROUTING_DIRECT_KEY, null, message.getBytes("UTF-8"));
  ```

- sub/pub mode: have exchange
  - direct/topic/fanout/header[不常用]是订阅者模式
  - 需要先启动消费者, 在启动生产者: 不启动消费者时[dobind], 生产者生成出的消息[只有 routingkey]不知道应该进入哪个 queue[没有 queue 与 exchange 通过 routingkey 绑定]. 启动消费者的时候会做 bind 并第一次声明出 queue, 关闭消费者时 queue 会消失且 bind 也会消失.
  - **`可以通过 在 sender 端 declare queue 和 dobind, 这样就可以改变为非订阅模式: 消息不会丢失`**
- queue 声明并不和 `routing key` 关联; 但是 publish 时会指定 `routing key` 和 `exchange`; 最终通过 `dobind` 将 `queue` 和 `exchange` 绑定时指定 `routing key`

  ```java
  // queue declare
  Queue.DeclareOk queueDeclare(String queue, boolean durable, boolean exclusive, boolean autoDelete, Map<String, Object> arguments) throws IOException;
  // channel.queueDeclare(Constants.QUEUE_NAME, false, false, false, null);

  // exchange declare
  Exchange.DeclareOk exchangeDeclare(String exchange, BuiltinExchangeType type) throws IOException;
  // channel.exchangeDeclare(Constants.EXCHANGE_NAME, BuiltinExchangeType.TOPIC);

  // binding
  Queue.BindOk queueBind(String queue, String exchange, String routingKey) throws IOException;
  // channel.queueBind(Constants.QUEUE_NAME, Constants.EXCHANGE_NAME, Constants.ROUTING_KEY);

  // publish
  // 会向所有满足条件的 queue 都放一份
  void basicPublish(String exchange, String routingKey, BasicProperties props, byte[] body) throws IOException;
  // channel.basicPublish(Constants.EXCHANGE_NAME, Constants.ROUTING_KEY, pro, message.getBytes("UTF-8"));

  // consume
  String basicConsume(String queue, boolean autoAck, DeliverCallback deliverCallback, CancelCallback cancelCallback) throws IOException;
  // channel.basicConsume(queueName, ack=true, deliverCallback, consumerTag -> { });
  ```

## 补充

1. AMQP proctrol concept

   - Server: Broker, 接受 client 连接, 实现 AMQP 实体服务
   - Connection: 应用程序和 Broker 的网络连接
   - Channel: 网络信道, 读写都是在 Channel 中进行[NIO 的概念], 包括对 MQ 进行的一些操作[例如 clear queue 等]都是在 Channel 中进行, 客户端可建立多个 Channel, 每个 Channel 代表一个会话任务
   - Message: 由 properties[有消息优先级、延迟等特性]和 Body[消息内容]组成
   - Virtual host: 用于消息隔离[类似 Redis 16 个 db 这种概念], 最上层的消息路由, 一个包含若干 Exchange 和 Queue, 同一个里面 Exchange 和 Queue 的名称不能存在相同的
   - Exchange: Routing and Filter
   - Binding: 把 Exchange 和 Queue 进行 Binding
   - Routing key: 路由规则
   - Queue: 物理上存储消息

## Reference

1. Message confirmation mechanism

   - https://blog.csdn.net/u013256816/article/details/55515234
   - https://www.cnblogs.com/vipstone/p/9350075.html
   - https://www.cnblogs.com/MuNet/p/8546192.html

2. sequence consume

   - https://www.cnblogs.com/huigelaile/p/10928984.html

3. rabbitmqctl

   - https://www.rabbitmq.com/rabbitmqctl.8.html

4. rabbitmq-plugins reference

   - https://www.rabbitmq.com/rabbitmq-plugins.8.html

5. Memory
   - paramters of memory: [memory-limit](https://emacsist.github.io/2016/12/01/rabbitmq%E4%B8%AD%E7%9A%84%E5%86%85%E5%AD%98%E4%B8%8E%E6%B5%81%E9%87%8F%E6%8E%A7%E5%88%B6/)
6. https://blog.csdn.net/dingjianmin/article/details/121031996
7. https://blog.csdn.net/qq_42029989/article/details/122110784
