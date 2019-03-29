const url=
"https://newsapi.org/v2/top-headlines?country=in&apiKey=2f84c947feb3407987344a5ebc35d5d9";
export async function getNews(){
	let result =await fetch(url).then(response => response.json());
	return result.articles;
}
