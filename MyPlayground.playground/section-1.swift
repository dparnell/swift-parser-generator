// Playground - noun: a place where people can play


class Foobar {
    var op : () -> ()
    
    init(op: () -> ()) {
        self.op = op
    }
    
    func go() {
        op()
    }
}


var x = Foobar { println("Stuff") }


x.go()
x.go()
