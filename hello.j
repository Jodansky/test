function myfunc()
{
   call printf("hello world!\n");
}

program
{
   call myfunc();
   call printf("a computed value is: %d\n", 31+74+275);
}