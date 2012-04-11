Zucchini - An Erlang INI parser
===============================

## Example

```erl-sh
1> zucchini:parse_string("
1> [pumpkin]
1> variety = winter
1> name = Pumpkin ; mmm, pumpkin pie
1> fortune = \"Pumpkin carving = Awesome\"
1> weight = 3.3
1> amount = 2
1>
1> [yellow] ; It's just called Yellow!
1> variety = summer
1> name = Yellow Squash
1> weight = 0.3
1> amount = 3
1> ").
{ok,[{pumpkin,[{variety,winter},
               {name,"Pumpkin"},
               {fortune,"Pumpkin carving = Awesome"},
               {weight,3.3},
               {amount,2}]},
     {yellow,[{variety,summer},
              {name,"Yellow Squash"},
              {weight,0.3},
              {amount,3}]}]}
```
