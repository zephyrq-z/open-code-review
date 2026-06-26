const x = 42;

async function fetchData(url: string): Promise<unknown> {
	const response = await fetch(url);
	return response.json();
}