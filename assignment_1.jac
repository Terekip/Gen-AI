#This is a simple Jac program that defines a function and prints its return value.
#It showcases the basic syntax and structure of a Jac program,
#The `def` keyword is used to define a function in Jac.
#The `return` keyword is used to return a value from the function.
def lovejac() -> str{
    return "With jac python is great!";
}
#The function `lovejac` returns a string, which is then printed in the entry block.
#The output will be "With jac python is great!" when the program is executed.

with entry:__main__{
    print(f"{lovejac()}");

}
#The `with entry` block is used to execute code when the program starts.
#The `print` function is used to output the string to the console.







