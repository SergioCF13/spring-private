package com.example.demo;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.core.env.Environment;

@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

@RestController
class HelloController {
    @Autowired
    private Environment environment;

    @GetMapping("/")
    public String hello() {
        String port = environment.getProperty("local.server.port");
        return "¡Bienvenido! Aplicación Spring Boot Presentación Final version canary. Versión actual corriendo en el puerto: " + port + ".";
    }
    @GetMapping("/health")
    public String health(){
        return "Health Check passed! deployed successfully.";
    }
    @GetMapping("/instance")
    public String instance(){
        String port = environment.getProperty("local.server.port");
        return "Instancia corriendo en port: " + port;
    }
}
