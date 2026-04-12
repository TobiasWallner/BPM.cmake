#include <libDepC.hpp>
#include <libC.hpp>
#include <libB/libB.hpp>

template<typename T>
void use([[maybe_unused]]const T&){}

int main(){
    const bool b = libB::libB();
    use(b);

    const int num = libC::get_number();
    use(num);

    std::string str = libDepC::get_number_str();
    use(str);
}