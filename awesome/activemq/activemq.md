## active mq

### [install activemq](../common/docker/docker.md#install-activemq)

```shell
cd ACTIVEMQ_BIN
./activemq start xbean:file:/CONFIG_FILE_PATH
```

### mq dimension

- API send and receive
- MQ high avaliable
- MQ cluster and fault tolerant configuration
- MQ durable
- MQ delayed delivery and timed delivery
- MQ ACK
- Spring integration
- Implementation language

### JMS

![avatar](/static/image/mq/mq-jms.png)

#### compoent

- JMS Provider: mq server
- JMS Producer
- JMS Consumer
- JMS Message

  - message header

    |      type       |                function                |
    | :-------------: | :------------------------------------: |
    | JMSDestination  |          message destination           |
    | JMSDeliveryMode | DeliveryMode.NON_PERSISTENT/PERSISTENT |
    |  JMSExpiration  |            set expire time             |
    |   JMSPriorty    |             0-9 default 4              |
    |  JMSMessageID   |         unique message signal          |
    |       ...       |                  ...                   |

  - message property: use for `specific paramter`, such as SERVICE, ACTION; `avoid duplicate`, `specific mark`
  - message body: Encapsulate specific message content

    | message type  |           function            |
    | :-----------: | :---------------------------: |
    |  TextMessage  |         common string         |
    |  MapMessage   | key: string; value: java type |
    | BytesMessage  |            bytes[]            |
    | StreamMessage |       java stream data        |
    | ObjectMessage |       serialize object        |

#### high available

- cluster[Replicated LevelDB Store + Zookeeper]
- persistence

  - queue producer: the previous message will be restore.

    ```java
    // producer
    connection.start();
    ...
    producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT);

    // consumer
    connection.start();
    ...
    MessageConsumer consumer = session.createConsumer(topic);
    ```

  - topic producer: the previous message will be missing.

    ```java
    // publisher
    producer.setDeliveryMode(DeliveryMode.NON_PERSISTENT);
    connection.start();

    // subscriber
    TopicSubscriber topicSubscriber = session.createDurableSubscriber(topic, UUID.randomUUID().toString());
    connection.start();
    ```

  - message:

    ```java
    message.setJMSDeliveryMode(DeliveryMode.PERSISTENT);
    ```

- acknowledge[consumer]

  |        type         |              function              | transaction |          code          |
  | :-----------------: | :--------------------------------: | :---------: | :--------------------: |
  |  AUTO_ACKNOWLEDGE   |          default auto ack          |    false    |                        |
  | CLIENT_ACKNOWLEDGE  |           Manual receipt           |    false    | message.acknowledge(); |
  | DUPS_OK_ACKNOWLEDGE |   allow part duplicated message    |    false    |
  | SESSION_TRANSACTED  | open transactin so ack is not work |    true     |

- transaction[producer]

  ```java
  // producer
  Session session = connection.createSession(true, Session.AUTO_ACKNOWLEDGE);
  ...
  session.commit(); // for rollback

  // consumer
  // if the consumer open transaction, must be use commit;
  // otherwise it will lead message duplicated conusmer.
  ```

- store in db

##### durable in db[mysql/kahadb/journal]

###### kahadb: DB sys based on file

- dir

  ```js
  kahadb: BTree
   ├── db-1.log: store data
   ├── db.data: store index
   ├── db.redo: recovery BTree
   ├── db.free: free page in data
   └── lock
  ```

- mysql dir

  ```js
  user.frm: table structure
  user.MYD: data
  user.MYI: index
  user.ibd: belong to InnoDB
  ```

###### JDBC

1. add `mysql-connector-java-5.1.48.jar` to /lib
2. config persistenceAdapter in `activemq.xml`:

   ```xml
   <!-- createTablesOnStartup: first is true to create tables, then change to false -->
   <!-- createTablesOnStartup: create tables when startup -->
   <persistenceAdapter>
      <jdbcPersistenceAdapter dataSource="#mysql-ds" createTablesOnStartup="true"/>
   </persistenceAdapter>

   <!-- below tag </broker> and before <import> -->
   <bean id="mysql-ds" class="org.apache.commons.dbcp2.BasicDataSource" destroy-method="close">
      <property name="driverClassName" value="com.mysql.jdbc.Driver"/>
      <property name="url" value="jdbc:mysql://101.132.45.28:3306/activemq?relaxAutoCommit=true"/>
      <property name="username" value="root"/>
      <property name="password" value="Yu******"/>
      <property name="maxTotal" value="200"/>
      <property name="poolPreparedStatements" value="true"/>
   </bean>
   ```

3. tables

   ```sql
   -- ACTIVEMQ_ACKS
   CREATE TABLE `ACTIVEMQ_ACKS` (
       `CONTAINER` varchar(250) NOT NULL COMMENT DESTINATION,
       `SUB_DEST` varchar(250) DEFAULT NULL COMMENT StaticInfo,
       `CLIENT_ID` varchar(250) NOT NULL COMMENT SUBSCRIBERID,
       `SUB_NAME` varchar(250) NOT NULL COMMENT SUBSCRIBERNAME,
       `SELECTOR` varchar(250) DEFAULT NULL COMMENT SELECTOKMSG,
       `LAST_ACKED_ID` bigint(20) DEFAULT NULL COMMENT CONSUMEDMSG,
       -- default PRIORITY is 5, 0-4: will not seq, but will Prior to 6-9
       `PRIORITY` bigint(20) NOT NULL DEFAULT '5',
       `XID` varchar(250) DEFAULT NULL,
       PRIMARY KEY (`CONTAINER`,`CLIENT_ID`,`SUB_NAME`,`PRIORITY`),
       KEY `ACTIVEMQ_ACKS_XIDX` (`XID`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

   -- ACTIVEMQ_LOCK
   CREATE TABLE `ACTIVEMQ_LOCK` (
       -- FOR CLUSTER
       `ID` bigint(20) NOT NULL,
       `TIME` bigint(20) DEFAULT NULL,
       `BROKER_NAME` varchar(250) DEFAULT NULL,
       PRIMARY KEY (`ID`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

   -- ACTIVEMQ_MSGS
   CREATE TABLE `ACTIVEMQ_MSGS` (
       `ID` bigint(20) NOT NULL COMMENT AUTOINCR,
       `CONTAINER` varchar(250) DEFAULT NULL COMMENT DESTINATION,
       -- MSGID_PROD + MSGID_SEQ = JMS MESSAGEID
       `MSGID_PROD` varchar(250) DEFAULT NULL COMMENT PRODUCERID,
       `MSGID_SEQ` bigint(20) DEFAULT NULL COMMENT MSGSQUENCE,
       `EXPIRATION` bigint(20) DEFAULT NULL COMMENT MSGEXPIRATION,
       `MSG` longblob  COMMENT MSGBINCONTENT,
       `PRIORITY` bigint(20) DEFAULT NULL COMMENT 0-9,
       `XID` varchar(250) DEFAULT NULL,
       PRIMARY KEY (`ID`),
       KEY `ACTIVEMQ_MSGS_MIDX` (`MSGID_PROD`,`MSGID_SEQ`),
       KEY `ACTIVEMQ_MSGS_CIDX` (`CONTAINER`),
       KEY `ACTIVEMQ_MSGS_EIDX` (`EXPIRATION`),
       KEY `ACTIVEMQ_MSGS_PIDX` (`PRIORITY`),
       KEY `ACTIVEMQ_MSGS_XIDX` (`XID`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
   ```

4. producer should be enable DeliveryMode.PERSISTENT

   ```java
   producer.setDeliveryMode(DeliveryMode.PERSISTENT);
   ```

5. notice

   ```markdown
   QUEUE: when produce message will insert data in table `ACTIVEMQ_MSGS`, consume message will delete data.
   TOPIC: subscriber durable in `ACTIVEMQ_ACKS`, and the message will be store in db.
   ```

###### JDBC Journaling

2. config persistenceAdapter in `activemq.xml`:

   ```xml
   <persistenceFactory>
       <journalPersistenceAdapterFactory
               journalLogFiles="4"
               journalLogFileSize="32768"
               useJournal="true"
               useQuickJournal="true"
               dataSource="#mysql-ds"
               dataDirectory="activemq-data"/>
   </persistenceFactory>
   ```

3. message will be record in db, donot be deleted

### JMS consumer and producer

- common
  - many consumer will consume message in fair.
- queue: load_balance
- topic: sub_pub
  - fisrt start consumer, or the message may not be consumed.
  - `subscribe status`
    - `没有订阅`: `订阅之前的消息不可收到`
    - `已订阅`: `订阅之后的消息可以收到`
    - `订阅后在线`: `消息都可以收到`
    - `订阅后离线`: `上线之后可以收到之前的消息-- clientID 必须一样; 如果 clientID 是 random 的, 则离线时的消息都不可以收到, 除非将message store in db`

### broker

- activemq instance: impliment by java code

### spring quick start

- dependencies

  ```xml
  <dependencies>
      <dependency>
          <groupId>org.apache.commons</groupId>
          <artifactId>commons-pool2</artifactId>
          <version>2.6.0</version>
      </dependency>
      <dependency>
          <groupId>org.apache.activemq</groupId>
          <artifactId>activemq-broker</artifactId>
          <version>5.14.3</version>
      </dependency>
      <dependency>
          <groupId>org.apache.activemq</groupId>
          <artifactId>activemq-client</artifactId>
          <version>5.14.3</version>
      </dependency>
      <dependency>
          <groupId>org.apache.activemq</groupId>
          <artifactId>activemq-pool</artifactId>
          <version>5.14.3</version>
      </dependency>

      <!--1. SPRING-->
      <dependency>
          <groupId>org.springframework</groupId>
          <artifactId>spring-core</artifactId>
          <version>4.3.18.RELEASE</version>
      </dependency>
      <dependency>
          <groupId>org.springframework</groupId>
          <artifactId>spring-context</artifactId>
          <version>4.3.18.RELEASE</version>
      </dependency>
      <dependency>
          <groupId>org.springframework</groupId>
          <artifactId>spring-jms</artifactId>
          <version>4.3.18.RELEASE</version>
      </dependency>

      <dependency>
          <groupId>org.apache.xbean</groupId>
          <artifactId>xbean-spring</artifactId>
          <version>3.16</version>
      </dependency>

      <!-- junit -->
      <dependency>
          <groupId>junit</groupId>
          <artifactId>junit</artifactId>
          <version>4.12</version>
          <scope>test</scope>
      </dependency>

      <!--LOGGER jar-->
      <dependency>
          <groupId>ch.qos.logback</groupId>
          <artifactId>logback-classic</artifactId>
          <version>1.2.3</version>
      </dependency>
      <dependency>
          <groupId>ch.qos.logback</groupId>
          <artifactId>logback-core</artifactId>
          <version>1.2.3</version>
      </dependency>
  </dependencies>
  ```

- application.context

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <beans xmlns="http://www.springframework.org/schema/beans"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:context="http://www.springframework.org/schema/context"
      xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd   http://www.springframework.org/schema/context http://www.springframework.org/schema/context/spring-context.xsd">

      <context:component-scan base-package="cn.edu.ntu.spring.integration.activemq"/>
      <context:property-placeholder location="classpath:application.properties"/>

      <!-- config producer -->
      <bean id="jmsFactory" class="org.apache.activemq.pool.PooledConnectionFactory" destroy-method="stop">
          <property name="connectionFactory">
              <bean class="org.apache.activemq.ActiveMQConnectionFactory">
                  <property name="brokerURL" value="${activemq.url}"/>
              </bean>
          </property>
          <property name="maxConnections" value="100"/>
      </bean>

      <!-- config queue -->
      <bean id="destinationQueue" class="org.apache.activemq.command.ActiveMQQueue">
          <constructor-arg index="0" value="p2p_queue"/>
      </bean>
      <!-- config topic -->
      <bean id="destinationTopic" class="org.apache.activemq.command.ActiveMQTopic">
          <constructor-arg index="0" value="sub_topic"/>
      </bean>

      <!-- config listener: do not need start consumer -->
      <bean id="jmsContainer" class="org.springframework.jms.listener.DefaultMessageListenerContainer">
          <property name="connectionFactory" ref="jmsFactory"/>
          <property name="destination" ref="destinationQueue"/>
          <property name="messageListener" ref="myMessageListener"/>
      </bean>

      <!-- config JMS tool -->
      <bean id="jmsTemplate" class="org.springframework.jms.core.JmsTemplate">
          <property name="connectionFactory" ref="jmsFactory"/>
          <property name="defaultDestination" ref="destinationQueue"/>
          <property name="messageConverter">
              <bean class="org.springframework.jms.support.converter.SimpleMessageConverter"/>
          </property>
      </bean>
  </beans>
  ```

- producer

  ```java
  @Service
  public class Producer2Queue {
    private static final Logger LOGGER = LoggerFactory.getLogger(Producer2Queue.class);

    @Autowired private JmsTemplate jmsTemplate;

    public static void main(String[] args) {
        ApplicationContext applicationContext =
            new ClassPathXmlApplicationContext("applicationContext.xml");
        Producer2Queue producer = (Producer2Queue) applicationContext.getBean("producer2Queue");
        producer.jmsTemplate.send(
            session -> {
            TextMessage message = session.createTextMessage("Spring integration ActiveMQ!");
            LOGGER.info("Send text message: {} success.", message);
            return message;
            });
        LOGGER.info("Send message over!");
    }
  }
  ```

- consumer

  ```java
  @Service
  public class ConsumerFromQueue {
      private static final Logger LOGGER = LoggerFactory.getLogger(ConsumerFromQueue.class);

      @Autowired
      private JmsTemplate jmsTemplate;

      public static void main(String[] args) {
          ApplicationContext applicationContext =
                  new ClassPathXmlApplicationContext("applicationContext.xml");
          ConsumerFromQueue consumer = (ConsumerFromQueue) applicationContext.getBean("consumerFromQueue");
          // just get one message from queue
          String value = (String) consumer.jmsTemplate.receiveAndConvert();
          LOGGER.info("Consume text message: {} success!", value);
      }
  }
  ```

- can config listener: do not need start consumer

  ```java
  @Component
  public class MyMessageListener implements MessageListener {
      private static final Logger LOGGER = LoggerFactory.getLogger(MyMessageListener.class);

      @Override
      public void onMessage(Message message) {
          Optional.ofNullable(message).ifPresent(mg-> {
              TextMessage textMessage = (TextMessage) mg;
              try {
                  String text = textMessage.getText();
                  LOGGER.info("Consume text message: {} success.", text);
              } catch (JMSException jmsException) {
                  LOGGER.info("Failed to consume text message: {}, cause by {}.", textMessage, jmsException);
              }
          });
      }
  }
  ```

### spring boot

- the message is default persisten
- sender: queue/topic will also work;

```java
@SendTo("${queue-reply}")
// will forward message from queue to queue, or topic to topic
```

- receiver: queue/topic will work according to application.yml;
  - yml config + listener destionantion

### transaport

- config

  ```xml
  <!-- default: tcp; nio: better performance -->
  <transportConnectors>
      <transportConnector name="nio" uri="nio://0.0.0.0:61616"/>
      <transportConnector name="auto+nio" uri="auto+nio://0.0.0.0:61616?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
      <!-- <transportConnector name="openwire" uri="tcp://0.0.0.0:61616?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/> -->
      <transportConnector name="amqp" uri="amqp://0.0.0.0:5672?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
      <transportConnector name="stomp" uri="stomp://0.0.0.0:61613?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
      <transportConnector name="mqtt" uri="mqtt://0.0.0.0:1883?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
      <transportConnector name="ws" uri="ws://0.0.0.0:61614?maximumConnections=1000&amp;wireFormat.maxFrameSize=104857600"/>
  </transportConnectors>
  ```

- v1.13.0: port is consistent

  ```xml
  <transportConnector name="auto+nio" uri="auto+nio://0.0.0.0:61616"/>
  <!--
    tcp://101.37.174.197:61616
    nio://101.37.174.197:61616
  -->
  ```

## retry

- default: will retry 6 times

## interivew

1. 引入消息队列之后如何保证其高可用性
   - persistence
   - ack
   - transation
   - durable
   - cluster: zookeeper + replicateddb-leveldb-store
2. 异步投送:

   - default is async, except Specify sync mode or send persistence message without transaction
   - allow little data loss

   ```java
   // method 01
   public static final String NIO_ACTIVEMQ_URL = "nio://101.37.174.197:61613?jms.useAsyncSend=true";

    // method 02
    // ((ActiveMQConnectionFactory)connectionFactory).setUseAsyncSend(true);
    activeMQConnectionFactory.setUseAsyncSend(true);  // set async mode

    // method 03
    ((ActiveMQConnection)connection).setUseAsyncSend(true);
   ```

   - how to guarantee message send success: need receive callback

   ```java
   // 异步发送需要接受回执并有客户端在判断以此是否成功
   // 如果 MQ 宕机了, 此时生产者端内存内的消息都会丢失; 因此正确的异步发送是需要接受回调需要接受回调.
    // 1. create session
    ActiveMQConnection connection = (ActiveMQConnection) ActiveMQUtil.getConnection();
    connection.setUseAsyncSend(true); // set async send
    // if the arg of transacted is true, should be commit.
    Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
    // 2. create destination
    Queue queue = session.createQueue(QUEUE_NAME);
    // 3. create producer
    ActiveMQMessageProducer producer = (ActiveMQMessageProducer) session.createProducer(queue);
    producer.setDeliveryMode(DeliveryMode.PERSISTENT);

    // 4. create message and send
    for (int i = 0; i < 4; i++) {
      TextMessage textMessage = session.createTextMessage("p2p message: " + i);
      String messageID = UUID.randomUUID().toString();
      textMessage.setJMSMessageID(messageID);
      producer.send(
          textMessage,
          new AsyncCallback() {
            @Override
            public void onSuccess() {
              LOGGER.info(
                  "producer: {} send message[{}]: {} to queue: {} success.",
                  producer,
                  messageID,
                  textMessage,
                  QUEUE_NAME);
            }

            @Override
            public void onException(JMSException exception) {
              LOGGER.error(
                  "producer: {} send message[{}]: {} to queue: {} failed, exception info: {}",
                  producer,
                  messageID,
                  textMessage,
                  QUEUE_NAME,
                  exception);
            }
          });
    }
    // 5. close resource
    producer.close();
    connection.close();
    ActiveMQUtil.getSession(session);
   ```

3. 延时投送和定时投送

   - introduce

   |    Property name     |  type  |                                              description                                               |
   | :------------------: | :----: | :----------------------------------------------------------------------------------------------------: |
   | AMQ_SCHEDULED_DELAY  |  long  | The time in milliseconds that a message will wait before being scheduled to be delivered by the broker |
   | AMQ_SCHEDULED_PERIOD |  long  |   The time in milliseconds to wait after the start time to wait before scheduling the message again    |
   | AMQ_SCHEDULED_REPEAT |  int   |                    The number of times to repeat scheduling a message for delivery                     |
   |  AMQ_SCHEDULED_CRON  | String |                                  Use a Cron entry to set the schedule                                  |

   - config

   ```java
   <broker xmlns="http://activemq.apache.org/schema/core" brokerName="localhost" dataDirectory="${activemq.data}" schedulerSupport="true">
   error: Attribute "schedulerSupport" was already specified for element "broker".
   ```

   - ScheduleMessage

   ```java
    TextMessage textMessage = session.createTextMessage("p2p message: " + i);
    textMessage.setLongProperty(ScheduledMessage.AMQ_SCHEDULED_DELAY, delay);
    textMessage.setLongProperty(ScheduledMessage.AMQ_SCHEDULED_PERIOD, period);
    textMessage.setIntProperty(ScheduledMessage.AMQ_SCHEDULED_REPEAT, repeat);
   ```

4. 分发策略
5. activemq 的消息重试机制

   - when

   ```log
   1. client use transaction, then rollback in session.
   2. client use transaction, then donot commit or exception before commit
   3. client use CLIENT_ACKNOWLEDGE mode, the recover in session.
   ```

   - times and interval: 1 sec, 6 times
   - Redelivery Policy

   |         Property         | Default Value | Description                                                                                   |
   | :----------------------: | :-----------: | :-------------------------------------------------------------------------------------------- |
   |    backOffMultiplier     |       5       | The back-off multiplier.                                                                      |
   | collisionAvoidanceFactor |     0.15      | The percentage of range of collision avoidance if enabled.                                    |
   |  initialRedeliveryDelay  |     1000L     | The initial redelivery delay in milliseconds.                                                 |
   |   maximumRedeliveries    |       6       | Sets maximum redelivered time before considered a poisoned pill                               |
   |  maximumRedeliveryDelay  |      -1       | Sets maximum delivery delay when useExponentialBackOff option is set. -1: maximum be applied) |
   |                          |               | or put to Dead Letter Queue. -1 : unlimited redeliveries.                                     |
   |     redeliveryDelay      |     1000L     | The delivery delay if initialRedeliveryDelay=0 (v5.4).                                        |
   |  useCollisionAvoidance   |     false     | Should the redelivery policy use collision avoidance.                                         |
   |  useExponentialBackOff   |     false     | Should exponential back-off be used, i.e., to exponentially increase the timeout.             |

   - 有毒消息 Poison ACK: 6 time later

   ```java
    ActiveMQConnectionFactory activeMQConnectionFactory =
                new ActiveMQConnectionFactory(Constants.NIO_ACTIVEMQ_URL);

    RedeliveryPolicy queuePolicy = new RedeliveryPolicy();
    queuePolicy.setInitialRedeliveryDelay(100);
    queuePolicy.setRedeliveryDelay(1000);
    queuePolicy.setMaximumRedeliveries(2);
    activeMQConnectionFactory.setRedeliveryPolicy(queuePolicy);

    Connection connection = activeMQConnectionFactory.createConnection();
   ```

6. 死信队列

   - defualt all poison message in ActiveMQ.DLQ, can config by deadLetterQueue

   ```xml
   <deadLitterStrategy>
       <sharedDeadLetterStrategy deadLetterQueue="DLQ-QUEUE"/>
   </deadLitterStrategy>
   ```

   - custom specify DeadLetter

   ```xml
   <!-- Queue: ActiveMQ.DLQ.Queue -->
   <!-- Topic: ActiveMQ.DLQ.Topic -->
   <!--
        <policyEntry queue="> ">
        "> ": means apply it to all queue and topic
    -->
   <policyEntry queue="order">
        <!-- specify queue ORDER: ActiveMQ.DLQ.Queue.Order -->
        <deadLetterStrategy>
            <!-- order is queue -->
            <individualDeadLetterStrategy queuePrefix="DLQ." useQueueForQueueMessages="false"/>
            <!-- order is topic: useQueueForTopicMessages defualt ois true, and it means store topic's DeadLetter in Queue -->
            <individualDeadLetterStrategy topicPrefix="DLQ." useQueueForTopicMessages="true"/>
        </deadLetterStrategy>
   </policyEntry>
   ```

   - auto delete expire message: when need delete message other than send it to dead queue

   ```xml
   <policyEntry queue="order">
        <deadLetterStrategy>
            <!-- processExpired: default is true and means send expied message to dead queue -->
            <sharedDeadLetterStrategy processExpired="false"/>
        </deadLetterStrategy>
   </policyEntry>
   ```

   - send non-persistence message to dead queue

   ```xml
    <!-- defualt mq will not send non-persistence to dead queue -->
    <policyEntry queue="order">
        <deadLetterStrategy>
            <!-- processNonPersistence: default is false and means donnot send  non-persistence message to dead queue -->
            <sharedDeadLetterStrategy processNonPersistence="true"/>
        </deadLetterStrategy>
   </policyEntry>
   ```

7. 保证消息不被重复消费[幂等性]
   - 网络延迟传输过程中, 会造成 MQ 的消息重试过程中的重复消费
   - solution
     1. 如果消息会插入数据库数据, 给消息一个唯一的主键, 重复消费会导致错误.
     2. 引入 redis, 给消息分配一个全局的 ID, 消费过的消息以 k-v 存入, 每次读取之前都先查一下 redis.
