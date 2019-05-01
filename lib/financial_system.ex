defmodule FinancialSystem do
  @moduledoc """
  This module is responsable to implement the financial operations.
  """

  @behaviour FinancialSystem.Financial

  alias FinancialSystem.{Account, AccountState, Currency, FinHelper, Split}
  alias FinancialSystem.Currency.CurrencyRequest

  @doc """
    Create user accounts

  ## Examples
    FinancialSystem.create("Yashin Santos",  "EUR", "220")
  """
  @impl true
  def create(name, currency, value)
      when is_binary(name) and is_binary(currency) and is_binary(value) do
    with {:ok, currency_upcase} <- CurrencyRequest.currency_is_valid(currency),
         {:ok, value_in_integer} <- Currency.amount_do(:store, value, currency_upcase),
         true <- byte_size(name) > 0 do
      %Account{
        name: name,
        currency: currency_upcase,
        value: value_in_integer
      }
      |> AccountState.start()
    end
  end

  def create(_, _, _) do
    raise(ArgumentError,
      message:
        "First and second args must be a string and third arg must be a number in type string greater than 0."
    )
  end

  @doc """
    Show the value in account.

  ## Examples
    {_, pid} = FinancialSystem.create("Yashin Santos", "EUR", "220")

    FinancialSystem.show(pid)
  """
  @impl true
  def show(pid) when is_pid(pid) do
    Currency.amount_do(
      :show,
      AccountState.show(pid).value,
      AccountState.show(pid).currency
    )
  end

  def show(_), do: raise(ArgumentError, message: "Please insert a valid PID.")

  @doc """
    Deposit value in account.

  ## Examples
    {_, pid} = FinancialSystem.create("Yashin Santos", "EUR", "220")

    FinancialSystem.deposit(pid, "BRL", "10")
  """
  @impl true
  def deposit(pid, currency_from, value) when is_pid(pid) and is_binary(value) do
    with {:ok, _} <- CurrencyRequest.currency_is_valid(currency_from),
         {:ok, value_in_integer} <-
           Currency.convert(currency_from, AccountState.show(pid).currency, value) do
      AccountState.deposit(pid, value_in_integer)
    end
  end

  def deposit(_, _, _),
    do:
      raise(ArgumentError,
        message: "The first arg must be a pid and de second arg must be a number in type string."
      )

  @doc """
    Takes out the value of an account.

  ## Examples
    {_, pid} = FinancialSystem.create("Yashin Santos", "EUR", "220")

    FinancialSystem.withdraw(pid, "10")
  """
  @impl true
  def withdraw(pid, value) when is_pid(pid) and is_binary(value) do
    with {:ok, value_in_integer} <-
           Currency.amount_do(:store, value, AccountState.show(pid).currency),
         {:ok, _} <- FinHelper.funds(pid, value_in_integer) do
      AccountState.withdraw(
        pid,
        value_in_integer
      )
    end
  end

  def withdraw(_, _),
    do:
      raise(ArgumentError,
        message: "The first arg must be a pid and de second arg must be a number in type string."
      )

  @doc """
   Transfer of values ​​between accounts.

  ## Examples
    {_, pid} = FinancialSystem.create("Yashin Santos", "EUR", "220")
    {_, pid2} = FinancialSystem.create("Antonio Marcos", "BRL", "100")

    FinancialSystem.transfer("15", pid, pid2)
  """
  @impl true
  def transfer(value, pid_from, pid_to)
      when is_pid(pid_from) and is_pid(pid_to) and is_binary(value) do
    with {:ok, _} <- FinHelper.transfer_have_account_from(pid_from, pid_to) do
      withdraw(pid_from, value)

      deposit(pid_to, AccountState.show(pid_from).currency, value)
    end
  end

  def transfer(_, _, _),
    do:
      raise(ArgumentError,
        message:
          "The first arg must be a number in type string and the second and third args must be a pid."
      )

  @doc """
   Transfer of values ​​between multiple accounts.

  ## Examples
    {_, pid} = FinancialSystem.create("Yashin Santos", "BRL", "220")
    {_, pid2} = FinancialSystem.create("Antonio Marcos", "BRL", "100")
    {_, pid3} = FinancialSystem.create("Mateus Mathias", "BRL", "100")
    split_list = [%FinancialSystem.Split{account: pid2, percent: 80}, %FinancialSystem.Split{account: pid3, percent: 20}]

    FinancialSystem.split(pid, split_list, "100")
  """
  @impl true
  def split(pid_from, split_list, value)
      when is_pid(pid_from) and is_list(split_list) and is_binary(value) do
    with {:ok, _} <- FinHelper.percent_ok(split_list),
         {:ok, _} <- FinHelper.transfer_have_account_from(pid_from, split_list) do
      split_list
      |> FinHelper.unite_equal_account_split()
      |> Enum.map(fn %Split{account: pid_to, percent: percent} ->
        percent
        |> Currency.to_decimal()
        |> Decimal.div(100)
        |> Decimal.mult(Decimal.new(value))
        |> Decimal.to_string()
        |> transfer(pid_from, pid_to)
      end)
    end
  end

  def split(_, _, _),
    do:
      raise(ArgumentError,
        message:
          "The first arg must be a pid, the second must be a list with %Split{} and the third must be a number in type string."
      )
end
