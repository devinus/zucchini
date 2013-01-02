-module(zucchini_tests).

-include_lib("eunit/include/eunit.hrl").

-define(_parse_test(Expect),
    (fun(Input, _) ->
        {ok, Actual} = zucchini:parse(Input),
        {Input, ?_assertEqual(Expect, Actual)}
    end)).

whitespace_test_() ->
    {foreachx,
        fun(_) -> ok end,
        [
            {"[foo]\nbar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {<<"[foo]\nbar = baz">>, ?_parse_test([{foo, [{bar, baz}]}])},
            {" [foo]\nbar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[ foo]\nbar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo ]\nbar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo] \nbar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo]\n bar = baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo]\nbar= baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo]\nbar =baz", ?_parse_test([{foo, [{bar, baz}]}])},
            {"[foo]\nbar = baz ", ?_parse_test([{foo, [{bar, baz}]}])},
            {"  [  foo  ]  \n  bar  =  baz  ", ?_parse_test([{foo, [{bar, baz}]}])}
        ]
    }.
