var wat_files = [

];

function pool_add(pool_id,src,callback){
    var script = document.createElement('script');
    script.type = "text/javascript";
        script.addEventListener("load", (event)=>{
        console.log("script loaded :)");
        callback(script.innerHTML);
    });
    script.src = src;    
    document.getElementById('bath').appendChild(script);
}

function compile_wat(wat, imports, callback){
```
never mind this was wishful thinking it dont work xD
```

    WebAssembly.compile(wat).then(module => {
        WebAssembly.instantiate(module, imports).then(()=>{
            //keiner weiss warum
        })
    });

}
