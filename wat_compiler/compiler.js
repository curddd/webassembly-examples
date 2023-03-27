const wat_compiler = {

    init(){
        WebAssembly.compile_wat = wat_compiler.compile;
    },

    findClosingParen(string, at_idx) {
        let end_idx = at_idx+1;
        let count = 1;
        while (count > 0) {
            let c = string.charAt(end_idx)
            if (c == '(') {
                count++;
                continue;
            }
            if (c == ')') {
                count--;
            }
        }
        return end_idx;
    },

    compile(wat){

        if(wat[0]!='('){
            return;
        }



    },

    

}

wat_compiler.init();
