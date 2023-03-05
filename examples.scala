trait A:
  type S
  def out(): S
  def inp(x: S): Unit
  def inv(x: S): S

  def q(): this.type
  def w(x: this.type): Uni

class B extends A:
  override type S <: B
  override def out(): S = this.asInstanceOf[S]
  override def inp(x: S): Unit = x.out()
  override def inv(x: S): S = x

  def q() = this
  def w(x: this.type) = x.q()

class C extends B:
  def f(): Unit = println("C.f")

  override type S = C
  override def inp(x: C): Unit = x.f()

  override def q() = this
  override def w(x: this.type) = x.f()

def test(): Unit = {
  val b = B()
  b.inp(b.out())

  // Found: B#S Required: ?1.S
  // B().inp(B().out())

  C().out().f()

  // Found:    C; Required: (?1 : C)
  // C().w(C())
}

@main
def main() = {
  test()
}
