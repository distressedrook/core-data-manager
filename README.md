There will be a point in our life, as mobile engineers, we would have to write an application using a backend that would already have been faultily implemented. Any changes in the backend for the purposes of a cleaner implementation would have other undesired cost and time repercussions. In such times, we as developers, would have to cast our principles aside and find sanity by finding ways to do what we do best: writing efficient code.

On one such occasions, we had to build an app that had the following flow from the services perspective.

1. Any interaction by the user — saving content etcetera, would be stored locally and would be sent to the server

2. At every specified time interval, the app would have to send this saved information to the server and as a part of response, we would get all the relevant information about the user. This data set is pretty heavy.

3. The flow is uncompromisable and with the given constraints in hand, we had to develop the app and still keep it responsive.
If you are wondering about the challenges that might occur with this setup, here are some.
1. The flow requires us to purge the existing database and create a new one with the new data coming from the server.
2. The data set is heavy. Parsing JSON and saving it to the database is time-consuming, during which the app SHOULD be responsive. Blocking user interaction in this time is not an option since this is recurring.
3. The UI should update itself after the specified time interval i.e, after the response is successful.
The technology that we went to was Core Data and with the given requirements in hand it was critical to build a robust Core Data architecture with very less scope for errors. Here is a discussion of design decisions that we took to make the app responsive as much as possible.

### A note on Core Data

Core Data is not a relational database system. The framework exposes an object graph,  abstracting the underlying persistence mechanism (which could be relational or otherwise), the implementation of which is immaterial to us. iOS provides different types of persistent store types. Here is a good documentation on this.

### Design

While it would make sense to have a Data Access Layer in other technologies, porting this pattern from one context to other where it doesn’t make sense is bad. A DAL consolidates all the queries in one place; on the other hand, a better design would be to put the queries appropriate to a particular object on that class. And then leveraging polymorphism at both the instance level and the class level of the objects, you can expose relevant retrievals. This type of design keeps your code clean and flexible.

We would, however, need a manager class that maintains instances of `NSManagedObjectContext` rather than letting our application’s `AppDelegate` do it for us. This become highly relevant when our Core Data logic grows and we have multiple contexts running around our code freely. The code becomes unsafe during such scenarios, especially since `NSMangedObjectContext` is not thread safe. Core Data Manager decides on which thread the context should run. More on that later.

### One possible solution.

Supporting post iOS5, Apple came up with this beautiful concept of concurrency types, where you can maintain multiple MOCs (Managed Object Contexts) with different concurrency specifications. What this meant to us, was that we could move all the heavy operations of purging the database and inserting records which typically took 5-6 seconds, to a background thread.  In those 5-6 seconds the data that the user would see is stale, but the app would still remain responsive.

Now, the obvious question is, how can we maintain different instances of data — one on which we insert/delete and the other from which we read from the UI? The answer to that is, one context that will be running on the main thread will be used to read to the UI. And the another context will be used to insert the data. The main thread context will be the parent of the child and only after the updates are complete, the child will commit its changes to the parent. The parent will save this commit to the disk and asks the UI to refresh itself. All these contexts will be maintained by aCoreDataManager. Note that the saving operation will still be done on the main thread which might take a second the complete.

A second is a lot from a user’s perspective. If we could still optimise this, it would be great.

### A better solution

 
A better solution would be to maintain three contexts. A child context will run in the background, doing updations, a parent context will be responsible for showing data to the UI which will be running on the main thread, and a writer context will save to the disk in the background. Since writing to the store is done in background, that one second lag is gone.
The Writer context will maintain the persistent storage. The Main context will be the child of the Writer. With that, we were able to make the UI very smooth. The user will not find the UI laggy.

### Conclusion

Before we curse and complain about a faulty server side implementation, we should be optimistic about what we could do so that all such faults are hidden to the user making his experience fantastic through little optimisations and careful design. This will also enhance our knowledge about the framework and satisfy you with the feeling of having solved a very good problem.
