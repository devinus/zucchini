-module(zucchini).
-export([parse/1,file/1]).
-compile(nowarn_unused_vars).
-compile({nowarn_unused_function,[p/4, p/5, p_eof/0, p_optional/1, p_not/1, p_assert/1, p_seq/1, p_and/1, p_choose/1, p_zero_or_more/1, p_one_or_more/1, p_label/2, p_string/1, p_anything/0, p_charclass/1, p_attempt/4, line/1, column/1]}).



-spec file(file:name()) -> any().
file(Filename) -> {ok, Bin} = file:read_file(Filename), parse(Bin).

-spec parse(binary() | list()) -> any().
parse(List) when is_list(List) -> parse(list_to_binary(List));
parse(Input) when is_binary(Input) ->
  setup_memo(),
  Result = case 'sections'(Input,{{line,1},{column,1}}) of
             {AST, <<>>, _Index} -> AST;
             Any -> Any
           end,
  release_memo(), Result.

'sections'(Input, Index) ->
  p(Input, Index, 'sections', fun(I,D) -> (p_seq([p_zero_or_more(fun 'ignorable'/2), fun 'section'/2, p_zero_or_more(fun 'section'/2), p_zero_or_more(fun 'ignorable'/2)]))(I,D) end, fun(Node, Idx) -> 
    [_, Head, Tail, _] = Node,
    [Head | Tail]
 end).

'section'(Input, Index) ->
  p(Input, Index, 'section', fun(I,D) -> (p_seq([p_zero_or_more(fun 'ignorable'/2), p_string(<<"[">>), p_zero_or_more(fun 'ws'/2), fun 'section_key'/2, p_zero_or_more(fun 'ws'/2), p_string(<<"]">>), fun 'properties'/2]))(I,D) end, fun(Node, Idx) -> 
    [_, <<$[>>, _, Key, _, <<$]>>, Props] = Node,
    {Key, Props}
 end).

'properties'(Input, Index) ->
  p(Input, Index, 'properties', fun(I,D) -> (p_seq([fun 'property'/2, p_zero_or_more(fun 'property'/2)]))(I,D) end, fun(Node, Idx) -> 
    [Head, Tail] = Node,
    [Head | Tail]
 end).

'property'(Input, Index) ->
  p(Input, Index, 'property', fun(I,D) -> (p_seq([p_zero_or_more(fun 'ignorable'/2), fun 'property_key'/2, p_zero_or_more(fun 'ws'/2), p_string(<<"=">>), p_zero_or_more(fun 'ws'/2), p_choose([fun 'float'/2, fun 'integer'/2, fun 'boolean'/2, fun 'quoted_string'/2, fun 'string'/2])]))(I,D) end, fun(Node, Idx) -> 
    [_, Key, _, <<$=>>, _, Value] = Node,
    {Key, Value}
 end).

'section_key'(Input, Index) ->
  p(Input, Index, 'section_key', fun(I,D) -> (p_one_or_more(p_seq([p_not(p_seq([p_zero_or_more(fun 'ws'/2), p_string(<<"]">>)])), p_seq([p_not(fun 'crlf'/2), p_anything()])])))(I,D) end, fun(Node, Idx) -> binary_to_atom(iolist_to_binary(Node), utf8) end).

'property_key'(Input, Index) ->
  p(Input, Index, 'property_key', fun(I,D) -> (p_one_or_more(p_seq([p_not(p_seq([p_zero_or_more(fun 'ws'/2), p_string(<<"=">>)])), p_seq([p_not(fun 'crlf'/2), p_anything()])])))(I,D) end, fun(Node, Idx) -> binary_to_atom(iolist_to_binary(Node), utf8) end).

'digit'(Input, Index) ->
  p(Input, Index, 'digit', fun(I,D) -> (p_charclass(<<"[0-9]">>))(I,D) end, fun(Node, Idx) -> Node end).

'integer'(Input, Index) ->
  p(Input, Index, 'integer', fun(I,D) -> (p_seq([p_optional(p_string(<<"-">>)), p_one_or_more(fun 'digit'/2)]))(I,D) end, fun(Node, Idx) -> list_to_integer(binary_to_list(iolist_to_binary(Node))) end).

'float'(Input, Index) ->
  p(Input, Index, 'float', fun(I,D) -> (p_seq([p_optional(p_string(<<"-">>)), p_zero_or_more(fun 'digit'/2), p_string(<<".">>), p_one_or_more(fun 'digit'/2)]))(I,D) end, fun(Node, Idx) -> 
    list_to_float(binary_to_list(iolist_to_binary(case Node of
        [[], [], <<$.>>, Frac]  ->
            [<<"0.">>, Frac];
        [<<$->>, [], <<$.>>, Frac]  ->
            [<<"-0.">>, Frac];
        [[], Int, <<$.>>, Frac] ->
            [Int, <<$.>>, Frac];
        [<<$->>, Int, <<$.>>, Frac] ->
            [<<$->>, Int, <<$.>>, Frac]
    end)))
 end).

'boolean'(Input, Index) ->
  p(Input, Index, 'boolean', fun(I,D) -> (p_choose([p_string(<<"true">>), p_string(<<"false">>), p_string(<<"yes">>), p_string(<<"no">>), p_string(<<"on">>), p_string(<<"off">>)]))(I,D) end, fun(Node, Idx) -> 
    case Node of
        Node when Node =:= <<"true">>; Node =:= <<"yes">>; Node =:= <<"on">> ->
            true;
        Node when Node =:= <<"false">>; Node =:= <<"no">>; Node =:= <<"off">> ->
            false
    end
 end).

'string'(Input, Index) ->
  p(Input, Index, 'string', fun(I,D) -> (p_zero_or_more(p_seq([p_not(p_seq([p_zero_or_more(fun 'space'/2), p_choose([fun 'crlf'/2, fun 'comment'/2])])), p_anything()])))(I,D) end, fun(Node, Idx) -> 
    case Node of
        [] -> undefined;
        Node -> iolist_to_binary(Node)
    end
 end).

'quoted_string'(Input, Index) ->
  p(Input, Index, 'quoted_string', fun(I,D) -> (p_seq([p_string(<<"\"">>), p_zero_or_more(p_seq([p_not(p_string(<<"\"">>)), p_anything()])), p_string(<<"\"">>)]))(I,D) end, fun(Node, Idx) -> 
    case Node of
        [<<$">>, [], <<$">>] -> <<>>;
        [<<$">>, Str, <<$">>] -> iolist_to_binary(Str)
    end
 end).

'space'(Input, Index) ->
  p(Input, Index, 'space', fun(I,D) -> (p_charclass(<<"[\s\t]">>))(I,D) end, fun(Node, Idx) -> Node end).

'crlf'(Input, Index) ->
  p(Input, Index, 'crlf', fun(I,D) -> (p_choose([p_string(<<"\r\n">>), p_string(<<"\n">>), p_string(<<"\r">>)]))(I,D) end, fun(Node, Idx) -> Node end).

'ws'(Input, Index) ->
  p(Input, Index, 'ws', fun(I,D) -> (p_choose([fun 'space'/2, fun 'crlf'/2]))(I,D) end, fun(Node, Idx) -> Node end).

'comment'(Input, Index) ->
  p(Input, Index, 'comment', fun(I,D) -> (p_seq([p_string(<<";">>), p_zero_or_more(p_seq([p_not(fun 'crlf'/2), p_anything()])), fun 'crlf'/2]))(I,D) end, fun(Node, Idx) -> Node end).

'ignorable'(Input, Index) ->
  p(Input, Index, 'ignorable', fun(I,D) -> (p_choose([fun 'ws'/2, fun 'comment'/2]))(I,D) end, fun(Node, Idx) -> Node end).




p(Inp, Index, Name, ParseFun) ->
  p(Inp, Index, Name, ParseFun, fun(N, _Idx) -> N end).

p(Inp, StartIndex, Name, ParseFun, TransformFun) ->
  case get_memo(StartIndex, Name) of      % See if the current reduction is memoized
    {ok, Memo} -> %Memo;                     % If it is, return the stored result
      Memo;
    _ ->                                        % If not, attempt to parse
      Result = case ParseFun(Inp, StartIndex) of
        {fail,_} = Failure ->                       % If it fails, memoize the failure
          Failure;
        {Match, InpRem, NewIndex} ->               % If it passes, transform and memoize the result.
          Transformed = TransformFun(Match, StartIndex),
          {Transformed, InpRem, NewIndex}
      end,
      memoize(StartIndex, Name, Result),
      Result
  end.

setup_memo() ->
  put(parse_memo_table, ets:new(?MODULE, [set])).

release_memo() ->
  ets:delete(memo_table_name()).

memoize(Index, Name, Result) ->
  Memo = case ets:lookup(memo_table_name(), Index) of
              [] -> [];
              [{Index, Plist}] -> Plist
         end,
  ets:insert(memo_table_name(), {Index, [{Name, Result}|Memo]}).

get_memo(Index, Name) ->
  case ets:lookup(memo_table_name(), Index) of
    [] -> {error, not_found};
    [{Index, Plist}] ->
      case proplists:lookup(Name, Plist) of
        {Name, Result}  -> {ok, Result};
        _  -> {error, not_found}
      end
    end.

memo_table_name() ->
    get(parse_memo_table).

p_eof() ->
  fun(<<>>, Index) -> {eof, [], Index};
     (_, Index) -> {fail, {expected, eof, Index}} end.

p_optional(P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} -> {[], Input, Index};
        {_, _, _} = Success -> Success
      end
  end.

p_not(P) ->
  fun(Input, Index)->
      case P(Input,Index) of
        {fail,_} ->
          {[], Input, Index};
        {Result, _, _} -> {fail, {expected, {no_match, Result},Index}}
      end
  end.

p_assert(P) ->
  fun(Input,Index) ->
      case P(Input,Index) of
        {fail,_} = Failure-> Failure;
        _ -> {[], Input, Index}
      end
  end.

p_and(P) ->
  p_seq(P).

p_seq(P) ->
  fun(Input, Index) ->
      p_all(P, Input, Index, [])
  end.

p_all([], Inp, Index, Accum ) -> {lists:reverse( Accum ), Inp, Index};
p_all([P|Parsers], Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail, _} = Failure -> Failure;
    {Result, InpRem, NewIndex} -> p_all(Parsers, InpRem, NewIndex, [Result|Accum])
  end.

p_choose(Parsers) ->
  fun(Input, Index) ->
      p_attempt(Parsers, Input, Index, none)
  end.

p_attempt([], _Input, _Index, Failure) -> Failure;
p_attempt([P|Parsers], Input, Index, FirstFailure)->
  case P(Input, Index) of
    {fail, _} = Failure ->
      case FirstFailure of
        none -> p_attempt(Parsers, Input, Index, Failure);
        _ -> p_attempt(Parsers, Input, Index, FirstFailure)
      end;
    Result -> Result
  end.

p_zero_or_more(P) ->
  fun(Input, Index) ->
      p_scan(P, Input, Index, [])
  end.

p_one_or_more(P) ->
  fun(Input, Index)->
      Result = p_scan(P, Input, Index, []),
      case Result of
        {[_|_], _, _} ->
          Result;
        _ ->
          {fail, {expected, Failure, _}} = P(Input,Index),
          {fail, {expected, {at_least_one, Failure}, Index}}
      end
  end.

p_label(Tag, P) ->
  fun(Input, Index) ->
      case P(Input, Index) of
        {fail,_} = Failure ->
           Failure;
        {Result, InpRem, NewIndex} ->
          {{Tag, Result}, InpRem, NewIndex}
      end
  end.

p_scan(_, [], Index, Accum) -> {lists:reverse( Accum ), [], Index};
p_scan(P, Inp, Index, Accum) ->
  case P(Inp, Index) of
    {fail,_} -> {lists:reverse(Accum), Inp, Index};
    {Result, InpRem, NewIndex} -> p_scan(P, InpRem, NewIndex, [Result | Accum])
  end.

p_string(S) when is_list(S) -> p_string(list_to_binary(S));
p_string(S) ->
    Length = erlang:byte_size(S),
    fun(Input, Index) ->
      try
          <<S:Length/binary, Rest/binary>> = Input,
          {S, Rest, p_advance_index(S, Index)}
      catch
          error:{badmatch,_} -> {fail, {expected, {string, S}, Index}}
      end
    end.

p_anything() ->
  fun(<<>>, Index) -> {fail, {expected, any_character, Index}};
     (Input, Index) when is_binary(Input) ->
          <<C/utf8, Rest/binary>> = Input,
          {<<C/utf8>>, Rest, p_advance_index(<<C/utf8>>, Index)}
  end.

p_charclass(Class) ->
    {ok, RE} = re:compile(Class, [unicode, dotall]),
    fun(Inp, Index) ->
            case re:run(Inp, RE, [anchored]) of
                {match, [{0, Length}|_]} ->
                    {Head, Tail} = erlang:split_binary(Inp, Length),
                    {Head, Tail, p_advance_index(Head, Index)};
                _ -> {fail, {expected, {character_class, binary_to_list(Class)}, Index}}
            end
    end.

line({{line,L},_}) -> L;
line(_) -> undefined.

column({_,{column,C}}) -> C;
column(_) -> undefined.

p_advance_index(MatchedInput, Index) when is_list(MatchedInput) orelse is_binary(MatchedInput)-> % strings
  lists:foldl(fun p_advance_index/2, Index, unicode:characters_to_list(MatchedInput));
p_advance_index(MatchedInput, Index) when is_integer(MatchedInput) -> % single characters
  {{line, Line}, {column, Col}} = Index,
  case MatchedInput of
    $\n -> {{line, Line+1}, {column, 1}};
    _ -> {{line, Line}, {column, Col+1}}
  end.
