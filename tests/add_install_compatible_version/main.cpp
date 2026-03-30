#include <libA.hpp>
#include <iostream>
int main(){
    std::string expected_version = "1.9.9";

    std::string libA_version = libA::version();

    std::cout << "expected: " << expected_version << std::endl;
    std::cout << "got: " << libA_version << std::endl;
    if(expected_version == libA_version){
        std::cout << "PASSED" << std::endl;
        return 0;
    }else{
        std::cout << "FAILED" << std::endl;
        return -1;
    }
}