---
title: Visually translating between <code>>>=</code> and <code>do</code>
layout: page
permalink: /translate-bind-do/
---

Let's define some types and functions we can use for illustration.

The code is adapted from the Haskell Wikibook[^1], § 32.3.

```
type Board = Int -- represents current game configuration

-- returns the possible game board configurations for the next turn.
nextConfigs :: Board -> [Board]
nextConfigs bd = [bd + 1, bd * 10]
```

For simplicity in the example, there is always a fixed number of next
turn configurations (2) for any given configuration, and next
configurations always follow the same formula (namely, `+1`, `*10`).

To find the list of possible game configurations after one turn, we
do:

```
ghci> bd = 3 :: Board -- a sample board to work with
ghci> nextConfigs bd
[4, 30]
```

To find the list of possible game configurations after *three*
turns, we could do:

```
> nextConfigs bd >>= nextConfigs >>= nextConfigs
[6,50,41,400,32,310,301,3000]
```

How can this be translated using do-notation?

## The translation: Overview

Start with the `>>=` notation.

```
nextConfigs bd >>= nextConfigs >>= nextConfigs
```

This is equivalently[^2]:

```
nextConfigs bd >>= (\ x -> nextConfigs x) >>= (\ y -> nextConfigs y)
```

Now we translate to do-notation:

```
do
  x <- nextConfigs bd
  y <- nextConfigs x
  nextConfigs y
```

Compare the last two code snippets visually.

The lambda argument names (`x` and `y`) become the assignment variable
names (`x` and `y`) in do-notation. The `nextConfigs <board>` function
calls become the action in each line in do-notation.

## The translation: Step-by-step

1. Start a `do` block. Begin scanning the `>>=` notation line from left
   to right.
```
do
```
2. Write down the first function call you encounter.
```
do
  nextConfigs bd
```
3. Add an arrow when you encounter `>>=`.
```
do
  <- nextConfigs bd
```
4. Write the name of the lambda argument and move to the next line.
```
do
  x <- nextConfigs bd
```
5. Repeat steps 2--4 until the end of the `>>=` notation line.

## Side notes

What is the type of the assignment variables `x` and `y` in the
do-notation? If one considered the `<-` as the traditional assignment
operator `=` in C, then one would think it to be `[Board]` since that is
the type of `nextConfigs <board>`.

But the type of `x` and `y` is not `[Board]`. It is `Board`, which is the
same as the type of `x` and `y` in the lambda arguments.

To get some inuition try adding this debug line in the middle of the
`do` block.

```
  traceM (show x) -- from Debug.Trace
```

Also try the code with other monads such as Maybe.

```
nextConfigs :: Board -> Maybe Board
nextConfigs bd = Just (bd + 1)
```

[^1]: https://en.wikibooks.org/wiki/Haskell
[^2]: This is true because `(\ x -> nextConfigs x)` is equivalent to `nextConfigs`.
