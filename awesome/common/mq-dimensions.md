## 核心

1. 消息队列技术选型
2. 高可靠、高可用和高性能
3. 消息不重复、不丢失
4. 性能
5. 扩展行: 水平
6. 社区

## 分布式系统

1. 最基本需求: 通信
2. 特点: 3v-3h
   - 3v
     - 海量
     - 实时
     - 多样
   - 3h
     - 高并发
     - 高可靠
     - 高性能
3. 底层技术面: 高性能通信、海量数据存储、高并发等.
4. 消息队列:
   - 功能简洁
   - 结构清晰
   - 入门简单
   - 深度足够

## knowledge list

![avatar](/static/image/mq/mq-knowledge-list.png)

1. 应用

   - 日志
   - 监控
   - 微服务
   - 流计算
   - ETL
   - IoT

2. 实现技术

   - **网络通信**
   - **序列化反序列化**
   - 数据压缩
   - **一致性协议**
   - **分布式事务**
   - 异步编程
   - **内存管理**
   - 文件与高性能 IO
   - 高可用分布式系统

## 哪些问题适合使用消息队列来解决

1. 异步处理: 秒杀

   ![avatar](/static/image/mq/mq-seckill.png)

2. 流量控制:

   - ~~自身能力范围内尽可能多地处理请求, 拒绝处理不了的请求并且保证自身运行正常~~
   - 使用消息队列隔离网关和后端服务, 以达到流量控制和保护后端服务的目的

   ![avatar](/static/image/mq/mq-seckill-access-control.png)

   - 能预估出秒杀服务的处理能力, 就可以用消息队列实现一个令牌桶
     - 单位时间内只发放固定数量的令牌到令牌桶中, 规定服务在处理请求之前必须先从令牌桶中拿出一个令牌,
     - 如果令牌桶中没有令牌, 则拒绝请求. 这样就保证单位时间内, 能处理的请求不超过发放令牌的数量, 起到了流量控制的作用.

   ![avatar](/static/image/mq/mq-seckill-token-bucket.png)

3. 服务解耦
4. 作为发布 / 订阅系统实现一个微服务级系统间的观察者模式
5. 连接流计算任务和数据
6. 用于将消息广播给大量接收者

## diff between MQ

1. rabbitmq 通过 EXCHANGE 将 `同一份消息` 发送到`多个 QUEUE`

    ![avatar](/static/image/mq/rabbitmq-topic.png)

2. 其他 MQ 产品是将消息发送到 TOPIC, 订阅者逻辑接受
   
   ![avatar](/static/image/mq/mq-topic.png)

![avatar](/static/image/mq/mq-comparison.jpg)

---

## issue

1. 消息堆积时不适合使用 RabbitMQ, 考虑使用 RocketMQ、Kafka 和 Pulsar
2. 为了确保消息的 `由于网络或服务器故障丢失`， **"请求 - 确认" 机制**
   - 生产者发送消息到 broker, broker 需要回复确认, 否则生产者会重发
   - 消费者正确消费 broker 的消息之后, 需要回复确认, 否则会给消费者重发这条消息
   - issue: 带来了消息的顺序消费的问题 `消息空洞`  `有序性`
     - 每个主题在任意时刻, 至多只能有一个消费者实例在进行消费, 
     - 那就没法通过水平扩展消费者的数量来提升消费端总体的消费性能.
     - 为了解决这个问题, RocketMQ 在主题下面增加了队列的概念

---

## reference

1. https://github.com/Alice52/java-ocean/issues/122