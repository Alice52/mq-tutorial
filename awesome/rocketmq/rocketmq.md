## RocketMQ

### concept

1. 生产者

   - producer 会往所有队列发消息, 但不是 "同一条消息每个队列都发一次", `每条消息只会往某个队列里面发送一次`
   - 怎么保证顺序呢? `4. 消息的一致性`: 本质上每二个 QUEUE 内的消息都是有序的消费的

2. RocketMQ 中, 订阅者的概念是通过消费组(Consumer Group)来体现的
   - 不同消费组之间完全独立
   - 同一消费组内竞争关系: 消息只消费一次
3. 消费位置(Consumer Offset)

   - 这个位置之前的消息都被消费过, 之后的消息都没有被消费过, 每成功消费一条消息, 消费位置就加一
   - 丢消息的原因大多是由于消费位置处理不当导致的
   - 在任何一个时刻, 某个 queue 在同一个 consumer group 中最多只能有一个 consumer 占用
   - RocketMQ 的发送消息默认策略是轮询选择每个 queue

   ![avatar](/static/image/mq/rocketmq.png)

4. 消息的一致性

   - 按照订单 ID 或者用户 ID, 用一致性哈希算法, 计算出队列 ID, 指定队列 ID 发送
   - 这样可以保证相同的订单/用户的消息总被发送到同一个队列上, 就可以确保严格顺序了

5. 分布式事务

   ![avatar](/static/image/mq/rocketmq-transaction.png)

   - 第 4 步的失败问题:

     - rocket mq: 事务反查的机制

       ![avatar](/static/image/mq/rocketmq-transaction2.png)

     - kafka: 会报错, 用户捕捉重试或者向前处理
