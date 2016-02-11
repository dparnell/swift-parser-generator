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


var x = Foobar { print("Stuff") }


x.go()
x.go()
