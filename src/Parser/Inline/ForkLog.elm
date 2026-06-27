module Parser.Inline.ForkLog exposing
    ( forklogBlue
    , forklogCyan
    , forklogRed
    , forklogYellow
    )

--
--debugCyan label width a = Debug.log (coloredLabel Console.black Console.bgCyan label width) a
--debugBlue label width a = Debug.log (coloredLabel Console.white Console.bgBlue label width) a


forklogRed a =
    forklog_ a


forklogYellow a =
    forklog_ a


forklogCyan : d -> d
forklogCyan a =
    forklog_ a


forklogBlue a =
    forklog_ a


forklog_ a =
    --let
    --    _ =
    --        Debug.log (coloredLabel fg bg label width) (f a)
    --in
    a
