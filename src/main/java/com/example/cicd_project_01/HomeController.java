package com.example.cicd_project_01;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping({"/", "/home"})
    public String home(){
        return "hello! world";
    }

    @GetMapping("/main")
    public String main(){
        return "here is main page";
    }
}
