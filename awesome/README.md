## mq

1. 是什么 mq: **最最基本的功能{接受消息, 保存下来, 等下可以被消费}**

   - 消息队列是一种**异步**的服务间通信方式， 适用于分布式和微服务架构间**解耦**: 可以削峰
   - 消息在被处理和删除之前一直存储在队列上

2. 基本元素

   - producer: 消息生产者, 负责产生和发送消息到 broker
   - broker：消息处理中心, 负责消息存储、确认、重试等, 一般其中会包含多个 queue
   - consumer：消息消费者, 负责从 broker 中获取消息, 并进行相应处理

3. 使用场景

   - 应用耦合: 发送方、接收方系统之间不需要了解双方, 只需要认识消息{项目初始需求不明确, 面向接口, 提高扩展性}
   - 异步处理: 多应用对消息队列中同一消息进行处理, 应用间并发处理消息, 相比串行处理, 减少处理时间
   - 限流削峰: 广泛应用于秒杀或抢购活动中, 避免流量过大导致应用系统挂掉的情况{节约成本}
   - 冗余: 消息数据能够采用`1:n`的方式, **供多个毫无关联的业务使用** (扩展性[增减下游处理系统])
   - 健壮性: 消息队列可以堆积请求, 所以消费端业务即使短时间死掉, 也不会影响主要业务的正常进行
   - ~~消息驱动的系统~~
   - **分布式事务的高并发解决方案**: 下单与减库存就不能是有此方案[数据具有实时的强一致性]

4. [dimension](./common/mq-dimensions.md)

   - ack
   - 持久化: 可靠性&安全性
   - 延时消费
   - 顺序消费
   - 异步投送
   - 保证消息不被重复消费[幂等性]
   - 性能瓶颈: 丢消息
   - retry
   - 事务
   - 高可用

5. mqs

   - activemq
   - rocketmq
   - rabbitmq
   - kafka
