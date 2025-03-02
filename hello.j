function myfunc()
{
   call printf("hello world!\n");
}

program
{
   call myfunc("first","second",42);
   call printf("a computed value is: %d\n", 31+74+275);
}