package com.abhiramkasu.crowdcue_backend.Configuration;

import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyState;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyUpdate;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.*;
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.JsonSerializer;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.boot.ssl.SslBundles;

import java.util.HashMap;
import java.util.Map;

@Configuration
public class KafkaConfig {

    @Bean
    public AdminClient kafkaAdminClient(KafkaProperties kafkaProperties, SslBundles sslBundles) {
        return AdminClient.create(kafkaProperties.buildAdminProperties(sslBundles));
    }

    @Bean
    public ProducerFactory<String, PartyUpdate> updateProducerFactory(KafkaProperties kafkaProperties) {
        Map<String, Object> configProps = new HashMap<>(kafkaProperties.buildProducerProperties(null));
        return new DefaultKafkaProducerFactory<>(configProps);
    }

    @Bean
    public KafkaTemplate<String, PartyUpdate> updateKafkaTemplate(ProducerFactory<String, PartyUpdate> producerFactory) {
        return new KafkaTemplate<>(producerFactory);
    }

    @Bean
    public ConsumerFactory<String, PartyState> partyStateConsumerFactory(KafkaProperties kafkaProperties) {
        Map<String, Object> configProps = new HashMap<>(kafkaProperties.buildConsumerProperties(null));
        return new DefaultKafkaConsumerFactory<>(configProps);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, PartyState> kafkaListenerContainerFactory(
            ConsumerFactory<String, PartyState> consumerFactory) {
        ConcurrentKafkaListenerContainerFactory<String, PartyState> factory = 
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory);
        return factory;
    }
}