package com.amazonaws.services.kinesisanalytics;

import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kinesis.FlinkKinesisConsumer;
import org.apache.flink.streaming.connectors.kinesis.config.ConsumerConfigConstants;
import org.apache.flink.api.common.serialization.SimpleStringEncoder;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;
import org.apache.flink.util.Collector;
import com.amazonaws.services.kinesisanalytics.runtime.KinesisAnalyticsRuntime;
import java.util.Map;
import java.util.Properties;
import java.sql.Timestamp;
import java.time.Instant;
import static java.util.Optional.ofNullable;

//import static software.amazon.kinesis.connectors.flink.config.AWSConfigConstants.AWS_REGION;

public class S3StreamingSinkJob {
    private static DataStream<String> createSourceFromStaticConfig(StreamExecutionEnvironment env) throws Exception {

        Map<String, Properties> applicationProperties = KinesisAnalyticsRuntime.getApplicationProperties();
        Properties properties = ofNullable(applicationProperties.get("ENVIRONMENT")).orElseGet(Properties::new);

        Properties inputProperties = new Properties();
        inputProperties.setProperty(ConsumerConfigConstants.AWS_REGION, properties.getProperty("REGION", "eu-central-1"));
        inputProperties.setProperty(ConsumerConfigConstants.STREAM_INITIAL_POSITION, "TRIM_HORIZON");
        return env.addSource(new FlinkKinesisConsumer<>(properties.getProperty("INPUT_STREAM", "ExampleInptStream"),
                new SimpleStringSchema(),
                inputProperties));
    }

    private static StreamingFileSink<String> createS3SinkFromStaticConfig() throws Exception {
        Map<String, Properties> applicationProperties = KinesisAnalyticsRuntime.getApplicationProperties();
        Properties properties = ofNullable(applicationProperties.get("ENVIRONMENT")).orElseGet(Properties::new);

        final StreamingFileSink<String> sink = StreamingFileSink
                .forRowFormat(new Path("s3a://" + properties.getProperty("BUCKET", "BucketExample") + "/data"), new SimpleStringEncoder<String>("UTF-8"))
                .build();
        return sink;
    }

    public static void main(String[] args) throws Exception {

        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        DataStream<String> input = createSourceFromStaticConfig(env);

        input.flatMap(new Tokenizer()) // Tokenizer for generating words
                .keyBy(0) // Logically partition the stream for each word
                .timeWindow(Time.minutes(5)) // Tumbling window definition
                .sum(1) // Sum the number of words per partition
                .map(value -> value.f0 +","+ value.f1.toString() +","+ Timestamp.from(Instant.now()).toString())
                .addSink(createS3SinkFromStaticConfig());

        env.execute("Flink S3 Streaming Sink Job");
    }

    public static final class Tokenizer
            implements FlatMapFunction<String, Tuple2<String, Integer>> {

        @Override
        public void flatMap(String value, Collector<Tuple2<String, Integer>> out) {
            String[] tokens = value.toLowerCase().split("\\W+");
            for (String token : tokens) {
                if (token.length() > 0) {
                    out.collect(new Tuple2<>(token, 1));
                }
            }
        }
    }
}