package com.example.cicd_project_01;


import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {

    @GetMapping({"/", "/home"})
    public String home(){
        return "hello! world";
    }

    @GetMapping("/main")
    public String main(){
        return "here is main page";
    }

    @GetMapping("/minjikim")
    public String main(){
        return "김민지 잠만보";
    }
}
