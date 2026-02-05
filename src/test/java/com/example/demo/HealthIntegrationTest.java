package com.example.demo;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class HealthIntegrationTest {
    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void healthEndpointReturnsExpectedMessage() {
        String response = this.restTemplate.getForObject("/health", String.class);
        assertEquals("Health check passed!", response);
    }
}
